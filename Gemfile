source "http://rubygems.org/"
ruby "2.2.0"

gem 'puma'

gem 'sinatra', github: 'sinatra/sinatra'
gem 'sinatra-contrib'

gem 'sequel'
gem 'pg'
gem 'redis'

gem 'omniauth'
gem 'omniauth-github'
gem 'omniauth-twitter'
gem 'omniauth-facebook'

gem 'sass'
gem 'sinatra-asset-pipeline', require: 'sinatra/asset_pipeline'
gem 'rack-flash3', require: 'rack-flash'
gem 'rack_csrf', require: 'rack/csrf'

gem 'kramdown'
gem 'nokogiri'
gem 'builder'
gem 'sanitize'
gem 'fastimage'
gem 'aws-sdk'
gem 'kronic'

group :production do
  gem 'newrelic_rpm'
end

group :development do
  gem 'dotenv'
  gem 'sqlite3'  # for doing data imports
end

group :test do
  gem 'rack-test'
  gem 'minitest'
  gem 'capybara'
  #gem 'capybara-webkit'
  gem 'minitest-capybara'
  gem 'rack_session_access'
  gem 'database_cleaner'
  gem 'launchy'
end
