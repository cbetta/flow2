require 'sinatra/asset_pipeline/task'
require './app'

Sinatra::AssetPipeline::Task.define! Flow::App

desc "Console"
task :console do
  require 'irb'
  ARGV.clear
  IRB.start
end

desc "Import posts from a RubyFlow v1 file"
task :import do
  require_relative 'lib/import'
  Flow::Import.import(ENV['database'])
end

desc "Delete all data"
task :reset do
	[Post,Comment,User].each { |k| k.all.each { |p| p.delete } }
end
