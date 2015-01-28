require 'bundler/setup'
Bundler.require

require 'sass'
require 'sinatra/base'
require 'sinatra/asset_pipeline'
require 'rack/csrf'
require 'sprockets-helpers'
require 'time'
require 'json'
require 'rack-flash'

if development?
  require 'dotenv'
  Dotenv.load
end

require_relative 'config/sequel'
require_relative 'config/redis'
require_relative 'config/aws'

require_relative 'lib/mirror_image'
require_relative 'lib/rate_limiter'
require_relative 'lib/sanitize_ext'

require_relative 'concerns/content'
require_relative 'concerns/validations'

require_relative 'models/config'
require_relative 'models/user'
require_relative 'models/post'
require_relative 'models/comment'

AUTH_PROVIDER = ENV['AUTH_PROVIDER'] || "GitHub"
ABOUT_PAGE = Post[uid: 'about']
DESCRIPTION_PAGE = Post[uid: 'description']

module Flow
  class App < Sinatra::Base
    configure do
      use Rack::Deflater
      use Rack::Session::Cookie,
                     :key => 'flow.session',
                     :path => '/',
                     :expire_after => 86400 * 60,
                     :secret => ENV["SECRET"] || "somethingsecrethere"

      register Sinatra::AssetPipeline
      set :sprockets, Sprockets::Environment.new(root)
      set :assets_prefix, '/assets'
      set :digest_assets, production?

      use Rack::Flash

      use OmniAuth::Builder do
        provider(:github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: 'user:email') if AUTH_PROVIDER.downcase == 'github'
        provider(:twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET'], scope: 'user:email') if AUTH_PROVIDER.downcase == 'twitter'
      end

      sprockets.append_path File.join(root, 'assets', 'css')
      sprockets.append_path File.join(root, 'assets', 'js')

      Sprockets::Helpers.configure do |config|
        config.environment = sprockets
        config.prefix      = assets_prefix
        config.digest      = digest_assets
        config.public_path = public_folder
        config.debug       = true if development?
      end

      require 'newrelic_rpm' if ENV['NEW_RELIC_LICENSE_KEY'] && production?
    end

    helpers do
      include Sprockets::Helpers
      include RateLimiter

      def h(text)
        Rack::Utils.escape_html(text)
      end

      def current_user
        session[:logged_in] && User[session[:logged_in]]
      end

      def logged_in?; current_user end

      def determine_page
        @offset = 0
        @page = 1

        if params[:page].to_i > 0
          @page = params[:page].to_i
          @offset = (@page - 1) * Post::POSTS_PER_PAGE
        end
      end

      def internal_visitor?
        request.referer && request.referer.include?(request.host)
      end

      def with_avatar
        current_user && current_user.avatar?
      end

      def admin?
        current_user && current_user.admin?
      end
    end

    before do
      # Classes we might wish to set on the <body> tag
      @body_classes = []

      # If the URL is www, redirect any non-www variants to it
      if ENV['BASE_URL'] =~ /\/\/www\./ && request.host !~ /^www/
        redirect request.url.sub(/\/\//, '//www.'), 301
      end

      # And vice versa (www to non-www)
      if ENV['BASE_URL'] !~ /\/\/www\./ && request.host =~ /^www/
        redirect request.url.sub(/www\./, ''), 301
      end
    end

    # Homepage
    get '/' do
      redirect '/rss', 301 if params[:format].to_s == 'rss'    # Compatibility with older flow sites

      rate_limit requests: 30, within: 40

      @body_classes << 'index'
      determine_page
      @posts = Post.recent_from_offset(@offset)

      if request.xhr?
        erb :posts, layout: false
      else
        # TODO: Hook up caching within the templates
        erb :index
      end
    end

    get '/rss' do
      @posts = Post.recent_from_offset(@offset)
      content_type :rss
      Cache[:posts_rss] ||= builder :posts
    end

    # Show an individual post's page
    get '/p/:id' do
      rate_limit requests: 30, within: 40

      id = params[:id].split('-').first
      @body_classes << 'post'
      @post = Post.find(uid: id)

      @editing = params[:edit] && params[:edit] == 'true'

      halt 403 if @editing && !@post.can_be_edited_by?(current_user)

      if @post
        @page_title = @post.title
      else
        status 404
      end

      # TODO: Hook up caching within the templates
      erb :post
    end


    # --- POSTING AND COMMENTING URLS
    # You can tell I really don't give a care about REST on this project so far ;-)
    # And I really don't.

    delete '/post/:uid' do
      post = Post.find_where_editable_by(current_user, uid: params[:uid])
      halt 404 unless post
      post.delete

      Cache.expire(:front_page)

      content_type :json
      erb({ success: true }.to_json, layout: false)
    end

    delete '/comment/:id' do
      comment = Comment.find_where_editable_by(current_user, id: params[:id])
      halt 404 unless comment
      comment.delete

      Cache.expire(:front_page)

      content_type :json
      erb({ success: true }.to_json, layout: false)
    end

    post '/post' do
      post = Post.find_where_editable_by(current_user, uid: params[:post_uid]) if params[:post_uid]

      if logged_in?
        post ||= Post.new
        post.title = params[:title]
        post.user ||= current_user
        post.content = params[:content]
        post.visible = false if current_user.metadata['shadowbanned']

        unless post.valid?
          content_type :json
          halt erb({ errors: post.errors_list }.to_json, layout: false)
        end

        if params[:preview]
          content_type :json
          halt erb({ preview: { title: post.title, content: post.rendered_content } }.to_json, layout: false)
        end

        unless within_rate_limit(:posting, requests: 1, within: 10)
          content_type :json
          halt erb({ errors: [['content', 'You have posted within the past five minutes']] }.to_json, layout: false)
        end

        post.save
        Cache.expire(:front_page)
        Cache.expire('post:' + post.uid)

        flash[:notice] = "Your post has been saved - thanks!"

        if request.xhr?
          content_type :json
          erb({ redirect_to_post: post.url }.to_json, layout: false)
        else
          redirect post.url
        end
      else
        content_type :json
        session[:return_to] = ENV['BASE_URL'] + "#submitform"
        erb({ redirect_to_oauth: AUTH_PROVIDER.downcase }.to_json, layout: false)
      end
    end

    post '/comment' do
      post = Post.find(uid: params[:post_id])

      comment = Comment.find_where_editable_by(current_user, id: params[:comment_id]) if params[:comment_id]

      halt 400 unless post

      if logged_in?
        comment ||= Comment.new
        comment.user = current_user
        comment.post = post
        comment.content = params[:content]

        unless comment.valid?
          content_type :json
          halt erb({ errors: comment.errors_list }.to_json, layout: false)
        end

        unless within_rate_limit(:commenting, requests: 6, within: 120)
          content_type :json
          halt erb({ errors: [['content', 'Slow down the commenting a little']] }.to_json, layout: false)
        end

        comment.save
        Cache.expire('post:' + comment.post.uid)      

        flash[:notice] = "Your comment has been posted - thanks!"

        if request.xhr?
          content_type :json
          erb({ redirect_to_post: comment.post.url, comment_id: comment.id }.to_json, layout: false)
        else
          redirect comment.post.url + "#comment-" + comment.id
        end
      else
        content_type :json
        session[:return_to] = post.url + "#postcomment"
        erb({ redirect_to_oauth: AUTH_PROVIDER.downcase }.to_json, layout: false)
      end
    end


    # --- AUTHENTICATION URLS

    get '/logout' do
      session[:logged_in] = false
      flash[:notice] = "You have logged out"
      redirect '/'
    end

    # OmniAuth callback used by external auth providers
    get '/auth/' + AUTH_PROVIDER.downcase + '/callback' do
      # Be sure we're receiving everything we want to receive
      r = request.env['omniauth.auth']
      halt 401 unless r.is_a?(Hash)

      provider = r['provider']
      uid = r['uid']
      halt 401 unless provider && uid && r['info']

      # Find if there's a user associated with the external ID being sent
      u = User.find(external_uid: uid)

      # If there is, we're logged in, hurrah.
      if u
        session[:logged_in] = u.id
      else
        # Otherwise, create a user based on the information received
        begin
          u = User.new
          u.username = r['info']['nickname']
          u.email = r['info']['email']
          u.metadata['provider'] = provider
          u.external_uid = uid
          u.external_token = r['credentials']['token']
          u.fullname = r['info']['name']

          # Do they have an image/avatar at the auth provider? If so, mirror it.
          if r['info']['image']
            fn = u.username.to_s + uid.to_s
            # Since it's not essential, we'll rescue this away if the upload fails
            u.avatar_url = MirrorImage.mirror_image_to_s3(r['info']['image'], fn) rescue nil
          end

          u.save
          session[:logged_in] = u.id
        rescue
          # If all else fails, I'm a Teapot.
          # TODO: This may occur if the username is not unique, so deal with it better!
          halt 418
        end
      end

      # We're logged in, we hope.
      flash[:notice] = "You are now logged in."

      if session[:return_to].to_s =~ /submitform/
        flash[:notice] = "You are now logged in and can submit your post to the site"
      end

      flash[:oauth_successful] = true

      # Return to what the user was doing, if we know what that was, otherwise the root URL
      redirect session[:return_to] || ENV['BASE_URL'] || '/'
    end

    # External auth failed
    get '/auth/failure' do
      # TODO: Show a nicer message than this
      erb "<h1>Authentication failed</h1>"
    end

    # The external auth provider isn't liking us
    get '/auth/:provider/deauthorized' do
      # TODO: Show a nicer message than this
      erb "#{params[:provider]} has deauthorized this app."
    end


    # --- COMPATIBILITY URLS

    # For compatibility with old flow sites for SEO/usability purposes
    get '/page/:page' do
      redirect(ENV['BASE_URL'] + "?page=" + params[:page], 301)
    end

    get '/items/:id' do
      redirect(ENV['BASE_URL'] + %{/p/#{params[:id]}}, 301)
    end

    get '/users/:id' do
      flash[:warning] = "User profile pages are not currently available, they will return soon"
      redirect ENV['BASE_URL']
    end

    get '/signup' do
      flash[:notice] = "You no longer need to sign up, just start posting"
      redirect ENV['BASE_URL']
    end

    get '/login' do
      flash[:notice] = "You no longer need to log in, it happens automatically when you try to do something"
      redirect ENV['BASE_URL']
    end

    # If this is being run directly, let it serve the app up
    run! if app_file == $0
  end
end
