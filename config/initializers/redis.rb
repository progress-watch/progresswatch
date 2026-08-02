# frozen_string_literal: true

# Progress and the Sidekiq queue are kept on separate logical databases so that
# flushing stale progress cannot drop undelivered notifications with it.
module ProgressWatch
  REDIS_URL = ENV.fetch('REDIS_URL', 'redis://localhost:6379')

  def self.redis_url_with_db(db)
    uri = URI.parse(REDIS_URL)
    uri.path = "/#{db}"
    uri.to_s
  end

  PROGRESS_REDIS_URL = ENV.fetch('PROGRESS_REDIS_URL') { redis_url_with_db(0) }
  SIDEKIQ_REDIS_URL  = ENV.fetch('SIDEKIQ_REDIS_URL')  { redis_url_with_db(1) }

  PROGRESS_KEY_PREFIX = ENV.fetch('PROGRESS_KEY_PREFIX', 'pw:progress')
  PROGRESS_TTL_SECONDS = Integer(ENV.fetch('PROGRESS_TTL_SECONDS', 86_400))

  PROGRESS_REDIS = ConnectionPool.new(size: Integer(ENV.fetch('RAILS_MAX_THREADS', 5))) do
    Redis.new(url: PROGRESS_REDIS_URL, timeout: 1.0, reconnect_attempts: 1)
  end
end
