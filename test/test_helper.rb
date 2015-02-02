ENV['RACK_ENV'] = 'test'
ENV['SITE_NAME'] = "TestFlow"

require 'minitest/autorun'
require 'rack/test'
require 'capybara'
require 'rack_session_access'
require 'rack_session_access/middleware'
require 'rack_session_access/capybara'
require 'minitest-capybara'
require 'database_cleaner'
require 'capybara/dsl'
require './app'

Capybara.app = Flow::App

DatabaseCleaner.strategy = :transaction

class Minitest::Spec
  include Rack::Test::Methods
  include Capybara::DSL
  include Capybara::Assertions

  before :each do
    DatabaseCleaner.start
    page.driver.block_unknown_urls rescue nil
  end

  after :each do
    DatabaseCleaner.clean
  end
end

# via https://gist.github.com/peterhellberg/2350832
class Capybara::Session
  def params
    Hash[*URI.parse(current_url).query.split(/\?|=|&/)]
  end
end
