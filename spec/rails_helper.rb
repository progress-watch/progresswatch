# frozen_string_literal: true

# A dedicated Redis database, because the suite flushes it between examples. Do not
# point this at db 0.
ENV['RAILS_ENV'] ||= 'test'
ENV['PROGRESS_REDIS_URL'] ||= 'redis://localhost:6379/15'

require 'spec_helper'
require_relative '../config/environment'
abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'

Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before do
    ProgressWatch::PROGRESS_REDIS.with(&:flushdb)
    PushDelivery.backend = PushDelivery::Log.new
  end
end
