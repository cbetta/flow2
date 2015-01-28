Sequel.extension(:pg_hstore, :pg_hstore_ops, :pg_array)

DB.disconnect if defined?(DB)
DB = Sequel.connect(ENV['DATABASE_URL'])

DB.run("CREATE EXTENSION hstore") rescue nil
DB.run("CREATE EXTENSION unaccent") rescue nil

# DB.loggers << Logger.new(STDOUT) if development?

class Sequel::Model
	plugin :schema
	plugin :after_initialize

	# TODO: Get these into concerns
	def errors_list
    list = []
    errors.each do |k, v|
      v.each do |msg|
        list << [k, msg]
      end
    end
    list
  end

  def self.find_where_editable_by(user, conditions)
    obj = find(conditions)
    return obj if obj.can_be_edited_by?(user)
  end

  def can_be_edited_by?(the_user)
  	the_user && (self.user == the_user || the_user.admin?)
  end
end
