# frozen_string_literal: true

source 'https://rubygems.org'

gem 'puma'
gem 'rails', '~> 8.1'

# Both adapters ship in the image. DATABASE_URL picks one at boot:
# sqlite3 for self-hosted, postgresql for cloud.
gem 'pg'
gem 'sqlite3'

# Volatile task state and the Sidekiq queue.
gem 'connection_pool'
gem 'redis'
gem 'sidekiq'

# Web UI. Same bundler as docuseal so frontend code moves between the two projects
# without a rewrite.
gem 'shakapacker'

# The only AWS dependency, and dormant unless AWS_SECRET_MANAGER_ID is set. See
# config/aws_secrets.rb for why the rule about no AWS in the application is broken here.
gem 'aws-sdk-secretsmanager', require: false

gem 'bootsnap', require: false
gem 'tzinfo-data', platforms: %i[windows jruby]

group :development, :test do
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
  gem 'rspec-rails'

  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
end
