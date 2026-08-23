# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
# require "active_storage/engine"
require 'action_controller/railtie'
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require 'action_view/railtie'
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative 'aws_secrets'

AwsSecrets.load!

module Progresswatch
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # `tasks` is not ignored, unlike the Rails default: the domain here is literally
    # called Task, so lib/tasks holds Tasks::Create and friends. Rake files are .rake
    # and Zeitwerk skips them, but a .rb helper dropped in there would break booting.
    config.autoload_lib(ignore: %w[assets])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Not api_only, because of the web UI — but the JSON endpoints stay on
    # ActionController::API and are pinned to format: :json in the routes, so a
    # browser's Accept header can never turn them into HTML under the CLI's feet.
    config.api_only = false
    config.i18n.available_locales = %i[en de es fr it nl pt]
    config.i18n.fallbacks = [:en]

    # Sessions exist for one reason: CSRF tokens on the two web forms. There are no
    # accounts and nothing else is ever stored in them.
    config.session_store :cookie_store, key: '_progresswatch_session', same_site: :lax

    config.active_job.queue_adapter = :sidekiq

    # Structured to stdout: containers write no log files.
    config.logger = ActiveSupport::Logger.new($stdout)
    config.logger.formatter = proc do |severity, time, _progname, message|
      "#{JSON.generate(level: severity, time: time.utc.iso8601(3), message: message.to_s.strip)}\n"
    end
    config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info')
  end
end
