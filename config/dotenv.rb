# frozen_string_literal: true

if ENV['RAILS_ENV'] == 'production'
  if !ENV['AWS_SECRET_MANAGER_ID'].to_s.empty?
    require 'aws-sdk-secretsmanager'
    require 'json'

    client = Aws::SecretsManager::Client.new

    secret_id = ENV.fetch('AWS_SECRET_MANAGER_ID', '')

    JSON.parse(client.get_secret_value(secret_id:).secret_string).each do |key, value|
      ENV[key] ||= value.to_s
    end
  elsif ENV['SECRET_KEY_BASE'].to_s.empty?
    require 'dotenv'
    require 'securerandom'

    dotenv_path = "#{ENV.fetch('WORKDIR', '.')}/progresswatch.env"

    unless File.exist?(dotenv_path)
      default_env = <<~TEXT
        DATABASE_URL= # keep empty to use sqlite or specify postgresql database URL
        SECRET_KEY_BASE=#{SecureRandom.hex(64)}
      TEXT

      File.write(dotenv_path, default_env, perm: 0o600)
    end

    database_url = ENV.fetch('DATABASE_URL', nil)

    Dotenv.load(dotenv_path)

    ENV['DATABASE_URL'] = ENV['DATABASE_URL'].to_s.empty? ? database_url : ENV.fetch('DATABASE_URL', nil)
  end

  if ENV['REDIS_URL'].to_s.empty?
    require 'digest'

    redis_password = Digest::SHA1.hexdigest("redis#{ENV.fetch('SECRET_KEY_BASE', '')}")

    ENV['REDIS_URL'] = "redis://default:#{redis_password}@127.0.0.1:16379/0"
    ENV['LOCAL_REDIS_URL'] = ENV.fetch('REDIS_URL', nil)
  end
end
