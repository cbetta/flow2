module RateLimiter
  $redis ||= Ohm.redis

  def within_rate_limit(key = :default, requests: 3, within: 240)
    # Create a key that uses the client's IP
    rate_key = 'rate:' + key.to_s + ':' + (defined?(request) ? request.ip : 'localhost')

    # TODO: Be a bit more intelligent about expiry, as things stand, 'overage' resets the counter even if it shouldn't
    req = if $redis.class == Redic
      $redis.call("INCR", rate_key)
      $redis.call("EXPIRE", rate_key, within)
    elsif $redis.class == Redis
      $redis.incr(rate_key)
      $redis.expire(rate_key, within)
    end
    
    req <= requests
  end

  def rate_limit(key = :default, requests: 3, within: 240)
    # No rate limiting in development mode
    return if settings.development?

    halt 429 unless within_rate_limit(key, requests: requests, within: within)
  end

  extend self
end
