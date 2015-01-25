require 'bundler/setup'
Bundler.require

require 'ohm'
require 'sinatra/base'
require 'sinatra/reloader' if development?
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

use OmniAuth::Builder do
  provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: 'user:email'
end

require_relative 'models/user'
require_relative 'models/post'
require_relative 'models/comment'

require_relative 'config/aws'
require_relative 'lib/mirror_image'

OKAY_ELEMENTS = %w{a em strong b br li ul ol}

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

      register Sinatra::Reloader if development?

      POSTS_PER_PAGE = ENV['POSTS_PER_PAGE'] || 10
    end

    helpers do
      include Sprockets::Helpers

      def h(text)
        Rack::Utils.escape_html(text)
      end

      def current_user
        session[:logged_in] && User[session[:logged_in]]
      end

      def determine_page
        @offset = 0
        @page = 1

        if params[:page].to_i > 0
          @page = params[:page].to_i
          @offset = (@page - 1) * POSTS_PER_PAGE
        end
      end
    end

    before do
      # Classes we might wish to set on the <body> tag
      @body_classes = []
    end

    # Homepage
    get '/' do
      redirect '/rss', 301 if params[:format].to_s == 'rss'    # Compatibility with older flow sites

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
      id = params[:id].split('-').first
      @body_classes << 'post'
      @post = Post.find(uid: id).first

      if @post
        @page_title = @post.title
      else
        status 404
      end

      erb :post
    end

    get '/logout' do
      session[:logged_in] = false
      redirect '/'
    end


    # OmniAuth callback
    get '/auth/github/callback' do
      r = request.env['omniauth.auth']

      halt 401 unless r.is_a?(Hash)

      provider = r['provider']
      uid = r['uid']

      halt 401 unless provider && uid && r['info']

      u = User.find(external_uid: uid).first

      if u
        session[:logged_in] = u.id
      else
        begin
          u = User.new
          u.username = r['info']['nickname']
          u.set_metadata email: r['info']['email']
          u.set_metadata provider: provider
          u.external_uid = uid
          u.external_token = r['credentials']['token']
          u.fullname = r['info']['name']

          if r['info']['image']
            fn = u.username.to_s + uid.to_s
            u.avatar_url = MirrorImage.mirror_image_to_s3(r['info']['image'], fn)
          end
          r['info']['nickname']
          r['info']['nickname']
          u.save
          session[:logged_in] = u.id
        rescue
          halt 418
        end
      end

      flash[:notice] = "You are now logged in"

      redirect '/'
    end

    get '/auth/failure' do
      erb "<h1>Authentication failed</h1><h3>message:<h3> <pre>#{params}</pre>"
    end

    get '/auth/:provider/deauthorized' do
      erb "#{params[:provider]} has deauthorized this app."
    end


    # For compatibility with old flow sites
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
