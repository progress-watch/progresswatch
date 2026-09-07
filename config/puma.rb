# frozen_string_literal: true

threads_count = Integer(ENV.fetch('RAILS_MAX_THREADS', 5))
threads threads_count, threads_count

# Do not add a `bind` line alongside this: port already binds 0.0.0.0, and the two
# together bind the same address twice and fail to start.
port ENV.fetch('PORT', 3000)

workers Integer(ENV.fetch('WEB_CONCURRENCY', 0))
preload_app! if Integer(ENV.fetch('WEB_CONCURRENCY', 0)) > 0

# Under Fargate's SIGTERM deadline, so in-flight requests finish instead of being
# killed mid-response.
worker_shutdown_timeout 25

require_relative '../lib/puma/plugin/sidekiq_embed'

plugin :tmp_restart
plugin :sidekiq_embed

pidfile ENV['PIDFILE'] if ENV['PIDFILE']
