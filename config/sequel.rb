# Add extensions for working with HStore columns more easily
Sequel.extension(:pg_hstore, :pg_hstore_ops, :pg_array)

# If the database is already defined, disconnect it
DB.disconnect if defined?(DB)

# Connect to the database
database_url = ENV[settings.environment.to_s.upcase + '_DATABASE_URL'] || ENV['DATABASE_URL']
DB = Sequel.connect(database_url, max_connections: 2)
DB.extension(:connection_validator)
DB.pool.connection_validation_timeout = 30

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
