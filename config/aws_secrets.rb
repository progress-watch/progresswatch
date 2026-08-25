# frozen_string_literal: true

module AwsSecrets
  module_function

  def load!
    id = ENV['AWS_SECRET_MANAGER_ID'].to_s
    return if id.empty?

    require 'aws-sdk-secretsmanager'
    require 'json'

    JSON.parse(Aws::SecretsManager::Client.new.get_secret_value(secret_id: id).secret_string)
        .each { |key, value| ENV[key] ||= value.to_s }
  end
end
