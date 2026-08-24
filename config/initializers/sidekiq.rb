# frozen_string_literal: true

require 'sidekiq'

# The web process reads the worker's heartbeat for the health check.
require 'sidekiq/api'

Sidekiq.configure_server do |config|
  config.redis = { url: ProgressWatch::SIDEKIQ_REDIS_URL }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ProgressWatch::SIDEKIQ_REDIS_URL }
end
