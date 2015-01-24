require 'bundler/setup'
Bundler.require
require 'ohm'
require 'sinatra/base'
require 'sinatra/asset_pipeline'
require 'rack/csrf'
require 'sprockets-helpers'

if development?
  require 'dotenv'
  Dotenv.load
end

use OmniAuth::Builder do
  provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: 'user:email'
end

module Flow
  class App < Sinatra::Base
    register Sinatra::AssetPipeline
    set :sprockets, Sprockets::Environment.new(root)
    set :assets_prefix, '/assets'
    set :digest_assets, false

    configure do
      REDIS_URL = ENV["REDISCLOUD_URL"] || ENV["REDIS_URL"] || "redis://127.0.0.1:6379"
      Ohm.redis = Redic.new(REDIS_URL)

      use Rack::Session::Cookie,
                           :key => 'flow.session',
                           :path => '/',
                           :expire_after => 86400 * 60,
                           :secret => ENV["SECRET"] || "somethingsecrethere"

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

      def h(text)
        Rack::Utils.escape_html(text)
      end
    end

    before do
      @body_classes = []
    end

    get '/' do
      erb :index
    end

    run! if app_file == $0
  end
end
