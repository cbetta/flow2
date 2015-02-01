class Config < Sequel::Model
  set_schema do
    primary_key :id, type: :varchar, auto_increment: false
    String :value, text: true
  end

  create_table unless table_exists?

  # Using a local hash as a naive cache to keep things lean
  @cache = {}

  def self.[](key)
  	@cache = {} unless ENV['RACK_ENV'] == 'production'
  	c = @cache[key.to_sym]
  	return c if c
  	@cache[key.to_sym] = super(key.to_s) && super(key.to_s).typed_value
  end

  def self.[]=(key, val)
  	unless obj = find(id: key.to_s)
  		obj = Config.new
  		obj.id = key.to_s
  	end

  	obj.value = val
  	obj.save
  	@cache[key.to_sym] = obj.typed_value
  end

  # We could use Postgres' built in array or json types here, but
  # we'll do it the cheap way as it's only for config information anyway
  def typed_value
  	val = value
  	if val && (val.start_with?('{') || val.start_with?('['))
  		return JSON.parse(val)
  	elsif val.to_i.to_s == val
  		return Integer(val)
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
