class Config < Sequel::Model
  set_schema do
    primary_key :id, type: :varchar, auto_increment: false
    String :value, text: true
  end

  create_table unless table_exists?

  @cache = {}

  def self.[](key)
  	@cache = {} unless ENV['RACK_ENV'] == 'production'
  	@cache[key.to_sym] ||= super(key.to_s).value
  end

  def self.[]=(key, val)
  	obj = find(id: key.to_s)
  	obj.value = val
  	obj.save
  	@cache[key.to_sym] = obj.value
  end

  # We could use Postgres' built in array or json types here, but
  # we'll do it the cheap way as it's only for config information anyway
  def value
  	val = super
  	if val && (val.start_with?('{') || val.start_with?('['))
  		return JSON.parse(val)
  	end
  	val
  end

  def value=(val)
  	if val.is_a?(Hash) || val.is_a?(Array)
  		super(val.to_json)
  	else
	  	super
  	end
  end
end
