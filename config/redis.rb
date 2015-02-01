REDIS = begin
	begin
		redis = Redis.new url: ENV["REDISCLOUD_URL"] || ENV["REDIS_URL"] || "redis://127.0.0.1:6379"
		redis.ping		# Do a ping to ensure the connection is formed and valid
		redis
	rescue
	end
end

# We can survive without Redis. Just.
puts "Redis NOT FOUND - caching and rate limiting disabled" unless REDIS

# A simple API for a caching mechanism
# Supporting gets with Cache[:x], sets with Cache[:x] = 10, and key expiry/deletion
class Cache
	# Default expiry for a key is 60 seconds
	EXPIRY = 60

	def self.[](key)
		return nil unless REDIS

		if val = REDIS.get("cache:" + key.to_s)
			return val
		end
	end

	def self.[]=(key, val, expiry = EXPIRY)
		return val unless REDIS

		REDIS.setex("cache:" + key.to_s, expiry, val)
		val
	end

	def self.expire(key)
		return unless REDIS

		REDIS.del("cache:" + key.to_s)
	end
end
