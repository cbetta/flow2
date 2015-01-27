require 'sinatra/asset_pipeline/task'
require './app'

Sinatra::AssetPipeline::Task.define! Flow::App

desc "Console"
task :console do
  require 'irb'
  ARGV.clear
  puts "You have access to User, Comment, and Post models."
  IRB.start
end

desc "Import posts from a RubyFlow v1 file"
task :import do
  require_relative 'lib/import'
  Flow::Import.import(ENV['database'])
end

desc "Delete all data in Redis"
task :reset_redis do
	puts "Are you REALLY SURE?"
	gets
  Ohm.redis.call "FLUSHDB"
end

desc "Delete all data in the main Postgres database"
task :reset_db do
	puts "Are you REALLY SURE?"
	gets
	DB.run("TRUNCATE users CASCADE")
	DB.run("TRUNCATE posts CASCADE")
	DB.run("TRUNCATE comments CASCADE")
end
