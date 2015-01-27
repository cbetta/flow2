Sequel.extension(:pg_hstore, :pg_hstore_ops, :pg_array)

DB = Sequel.connect(ENV['DATABASE_URL'])
DB.run("CREATE EXTENSION hstore") rescue nil

# DB.loggers << Logger.new(STDOUT) if development?

class Sequel::Model
	plugin :schema
	plugin :after_initialize

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
    return obj if obj.user == user || user.admin?
  end  
end
