# frozen_string_literal: true

# The one place the app knows it might be on AWS — a deliberate exception, see CLAUDE.md.
# Not an initializer: database.yml reads ENV while Rails is still initializing.
module AwsSecrets
  module_function

  def load!
    id = ENV['AWS_SECRET_MANAGER_ID'].to_s
    return if id.empty?

    require 'aws-sdk-secretsmanager'
    require 'json'

    # ||=: a value passed to the container wins over the secret.
    JSON.parse(Aws::SecretsManager::Client.new.get_secret_value(secret_id: id).secret_string)
        .each { |key, value| ENV[key] ||= value.to_s }
  end
end
