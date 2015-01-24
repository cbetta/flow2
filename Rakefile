require 'sinatra/asset_pipeline/task'
require './app'

Sinatra::AssetPipeline::Task.define! Flow::App

desc "Console"
task :console do
  require 'irb'
  ARGV.clear
  IRB.start
end
