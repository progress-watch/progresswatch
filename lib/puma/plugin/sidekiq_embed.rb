# frozen_string_literal: true

require 'erb'
require 'puma/plugin'
require 'yaml'

Puma::Plugin.create do
  def config(dsl)
    return unless embedded? && clustered?

    dsl.before_worker_boot { |index| boot_sidekiq if index.zero? }
    dsl.before_worker_shutdown { stop_sidekiq }
  end

  def start(launcher)
    return unless embedded? && !clustered?

    launcher.events.after_booted { boot_sidekiq }
    launcher.events.after_stopped { stop_sidekiq }
    launcher.events.before_restart { stop_sidekiq }
  end

  private

  def embedded?
    ENV['PW_EMBEDDED_WORKER'] != 'false'
  end

  def clustered?
    Integer(ENV.fetch('WEB_CONCURRENCY', 0)).positive?
  end

  def boot_sidekiq
    settings = YAML.safe_load(ERB.new(File.read(sidekiq_yml)).result, permitted_classes: [Symbol])

    @sidekiq = Sidekiq.configure_embed do |config|
      config.queues = settings[:queues]
      config.concurrency = Integer(settings[:concurrency])
      config[:timeout] = Integer(settings[:timeout])
    end

    @sidekiq.run
  end

  def stop_sidekiq
    @sidekiq&.stop
    @sidekiq = nil
  end

  def sidekiq_yml
    File.expand_path('../../../config/sidekiq.yml', __dir__)
  end
end
