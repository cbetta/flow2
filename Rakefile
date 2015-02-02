require 'sinatra/asset_pipeline/task'
require 'rake/testtask'
require './app'

Sinatra::AssetPipeline::Task.define! Flow::App

desc "Console"
task :console do
  require 'irb'
  ARGV.clear
  puts "You have access to User, Comment, and Post models."
  IRB.start
end

desc "Import posts from a Flow v1 SQLite database"
task :import do
  require_relative 'lib/import'
  Flow::Import.import(ENV['database'], ENV['database_url'])
  puts "Import complete"
end

desc "Delete all data in Redis"
task :reset_redis do
	puts "Are you REALLY SURE? Ctrl+C now if not."
	STDIN.gets
  Ohm.redis.call "FLUSHDB"
  puts "Redis database flushed"
end

desc "Delete all data in the main Postgres database"
task :reset_db do
	puts "Are you REALLY SURE? Ctrl+C now if not."
	STDIN.gets
	%w{users posts comments}.each { |model| DB.run("DROP TABLE #{model} CASCADE") }
	puts "Tables dropped"
end

desc "Run tests"
Rake::TestTask.new do |t|
  t.pattern = "test/*_test.rb"
end
