# frozen_string_literal: true

# Reads configuration out of AWS Secrets Manager into ENV.
#
# This is the one place the application knows it might be running on AWS, and it is a
# deliberate exception to the rule that it must not — see CLAUDE.md. The alternative was
# a shell script on the instance rendering an env file before `docker run`, and a gem
# that stays dormant unless AWS_SECRET_MANAGER_ID is set was judged cheaper than a deploy
# step that only exists on one machine and cannot be tested anywhere.
#
# Not an initializer: database.yml and the Redis initializer both read ENV while Rails is
# initializing, so this has to run before that starts.
module AwsSecrets
  module_function

  def load!
    id = ENV['AWS_SECRET_MANAGER_ID'].to_s
    return if id.empty?

    require 'aws-sdk-secretsmanager'
    require 'json'

    # ||= and not []=: a value passed to the container explicitly wins over the secret,
    # so one setting can be overridden for one run without editing shared configuration.
    JSON.parse(Aws::SecretsManager::Client.new.get_secret_value(secret_id: id).secret_string)
        .each { |key, value| ENV[key] ||= value.to_s }
  end
end
