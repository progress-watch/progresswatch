# frozen_string_literal: true

source 'https://rubygems.org'

gem 'aws-sdk-secretsmanager', require: false
gem 'connection_pool'
gem 'pg'
gem 'puma'
gem 'rails', '~> 8.1'
gem 'redis'
gem 'rqrcode'
gem 'shakapacker'
gem 'sidekiq'
gem 'sqlite3'
gem 'web-push'

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
