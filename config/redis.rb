Ohm.redis = Redic.new(ENV["REDISCLOUD_URL"] || ENV["REDIS_URL"] || "redis://127.0.0.1:6379")
