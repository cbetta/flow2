require 'bundler/setup'
Bundler.require

require 'ohm'
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

require_relative 'models/user'
require_relative 'models/post'
require_relative 'models/comment'

AUTH_PROVIDER = ENV['AUTH_PROVIDER'] || "GitHub"
POST_ELEMENTS = %w{a em strong b br li ul ol p code tt samp}
COMMENT_ELEMENTS = POST_ELEMENTS + %w{img}
ABOUT_PAGE_PRESENT = Post[uid: 'about']
POSTS_PER_PAGE = ENV['POSTS_PER_PAGE'] || 25

use OmniAuth::Builder do
  provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: 'user:email' if AUTH_PROVIDER.downcase == 'github'
  provider :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET'], scope: 'user:email' if AUTH_PROVIDER.downcase == 'twitter'
end

module Flow
  class App < Sinatra::Base
    configure do
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
        provider :github, ENV["GITHUB_KEY"], ENV["GITHUB_SECRET"]
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
          @offset = (@page - 1) * POSTS_PER_PAGE
        end
      end

      def internal_visitor?
        request.referer && request.referer.include?(request.host)
      end

      def with_avatar
        current_user && current_user.avatar?
      end
    end

    before do
      # Classes we might wish to set on the <body> tag
      @body_classes = []
    end

    # Homepage
    get '/' do
      redirect '/rss', 301 if params[:format].to_s == 'rss'    # Compatibility with older flow sites

      rate_limit requests: 30, within: 40

      @body_classes << 'index'
      determine_page
      @posts = Post.all.sort(order: 'DESC', limit: [@offset, POSTS_PER_PAGE])

      if request.xhr?
        erb :posts, layout: false
      else
        erb :index
      end
    end

    get '/rss' do
      @posts = Post.all.sort(order: 'DESC', limit: [0, POSTS_PER_PAGE])
      content_type :rss
      builder :posts
    end

    # Show an individual post's page
    get '/p/:id' do
      rate_limit requests: 30, within: 40

      id = params[:id].split('-').first
      @body_classes << 'post'
      @post = Post.find(uid: id)

      if @post
        @page_title = @post.title
      else
        status 404
      end

      erb :post
    end




    # --- POSTING AND COMMENTING URLS

    post '/post' do
      if logged_in?
        post = Post.new
        post.title = params[:title]
        post.user = current_user
        post.content = params[:content]

        unless post.valid?
          content_type :json
          halt erb({ errors: post.errors_list }.to_json, layout: false)
        end

        post.save

        unless within_rate_limit(:posting, requests: 1, within: 10)
          content_type :json
          halt erb({ errors: [['content', 'You have posted within the past five minutes']] }.to_json, layout: false)
        end

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
      post = Post.find(uid: params[:post_id]).first
      comment = Comment[]
      halt 400 unless post

      if logged_in?
        comment = Comment.new
        comment.user = current_user
        comment.post = post
        comment.content = params[:content]

        unless comment.valid?
          content_type :json
          halt erb({ errors: comment.errors_list }.to_json, layout: false)
        end

        comment.save

        unless within_rate_limit(:commenting, requests: 4, within: 120)
          content_type :json
          halt erb({ errors: [['content', 'Slow down the commenting a little']] }.to_json, layout: false)
        end

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
      u = User.find(external_uid: uid).first

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
      flash[:notice] = "You are now logged in"
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
    get '/items/:id' do
      redirect %{/p/#{params[:id]}}
    end

    get '/users/:id' do
      redirect %{/}
    end

    get '/signup' do
      redirect %{/}
    end

    # If this is being run directly, let it serve the app up
    run! if app_file == $0
  end
end
