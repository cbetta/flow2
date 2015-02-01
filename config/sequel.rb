# Add extensions for working with HStore columns more easily
Sequel.extension(:pg_hstore, :pg_hstore_ops, :pg_array)

# If the database is already defined, disconnect it
DB.disconnect if defined?(DB)

# Connect to the database
DB = Sequel.connect(ENV['DATABASE_URL'])

# Try to create two extensions we want to use, but skip if they raise errors
DB.run("CREATE EXTENSION hstore") rescue nil
DB.run("CREATE EXTENSION unaccent") rescue nil

# Uncomment this if you want to see every database query logged
# DB.loggers << Logger.new(STDOUT) if development?

# Enable schema and after_initialize callback plugins on all models in this app
class Sequel::Model
	plugin :schema
	plugin :after_initialize
end
