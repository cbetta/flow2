REDIS = begin
	begin
		redis = Redis.new url: ENV["REDISCLOUD_URL"] || ENV["REDIS_URL"] || "redis://127.0.0.1:6379"
		redis.ping
		redis
	rescue
	end
end

puts "Redis NOT FOUND - caching and rate limiting disabled" unless REDIS

class Cache
	EXPIRY = 60

	def self.[](key)
		return nil unless REDIS
		
		if val = REDIS.get("cache:" + key.to_s)
			return val
		end
	end

	def self.[]=(key, val)
		return val unless REDIS
		
		REDIS.setex("cache:" + key.to_s, EXPIRY, val)
		val
	end

	def self.expire(key)
		return unless REDIS

		REDIS.del("cache:" + key.to_s)
	end
end
