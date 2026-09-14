# frozen_string_literal: true

require 'erb'
require 'puma/plugin'
require 'redis_client'
require 'yaml'

Puma::Plugin.create do
  def config(cfg)
    return if cfg.instance_variable_get(:@options)[:workers] <= 0

    cfg.before_worker_boot { start_sidekiq! }

    cfg.before_worker_shutdown { @sidekiq&.stop }
    cfg.before_refork { @sidekiq&.stop }
  end

  def start(launcher)
    launcher.events.after_booted do
      next if Puma.stats_hash[:workers].to_i != 0

      start_sidekiq!
    end

    launcher.events.after_stopped { Thread.new { @sidekiq&.stop }.join }
    launcher.events.before_restart { Thread.new { @sidekiq&.stop }.join }
  end

  def start_sidekiq!
    Thread.new do
      wait_for_redis!

      sidekiq_config = YAML.safe_load(ERB.new(File.read('config/sidekiq.yml')).result, permitted_classes: [Symbol])

      @sidekiq = Sidekiq.configure_embed do |config|
        config.queues = sidekiq_config[:queues]
        config.concurrency = Integer(sidekiq_config[:concurrency])
        config[:timeout] = Integer(sidekiq_config[:timeout])
      end

      @sidekiq.run
    end
  end

  def wait_for_redis!
    attempt = 0

    loop do
      attempt += 1

      sleep((attempt - 1) / 10.0)

      RedisClient.new(url: ProgressWatch::SIDEKIQ_REDIS_URL).call('GET', '1')

      break
    rescue RedisClient::CannotConnectError
      raise('Unable to connect to redis') if attempt > 30
    end
  end
end
