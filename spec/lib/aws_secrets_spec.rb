# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('config/aws_secrets')

RSpec.describe AwsSecrets do
  it 'does nothing without AWS_SECRET_MANAGER_ID' do
    expect(described_class.load!).to be_nil
  end

  context 'with a secret configured' do
    let(:client) { instance_double(Aws::SecretsManager::Client) }
    let(:secret) { { 'DATABASE_URL' => 'postgresql://from-secret', 'WEB_CONCURRENCY' => 2 } }

    before do
      require 'aws-sdk-secretsmanager'
      # CI exports DATABASE_URL and a developer's shell does not, so the keys the secret
      # carries are removed rather than assumed absent.
      environment = ENV.to_h.except(*secret.keys)
      stub_const('ENV', environment.merge('AWS_SECRET_MANAGER_ID' => '/progresswatch/production'))
      allow(Aws::SecretsManager::Client).to receive(:new).and_return(client)
      allow(client).to receive(:get_secret_value).with(secret_id: '/progresswatch/production')
                                                 .and_return(instance_double(
                                                               Aws::SecretsManager::Types::GetSecretValueResponse,
                                                               secret_string: secret.to_json
                                                             ))
    end

    it 'puts every key into ENV as a string' do
      described_class.load!

      expect(ENV.fetch('DATABASE_URL')).to eq('postgresql://from-secret')
      expect(ENV.fetch('WEB_CONCURRENCY')).to eq('2')
    end

    it 'leaves a value already in the environment alone' do
      ENV['DATABASE_URL'] = 'postgresql://from-the-container'

      described_class.load!

      expect(ENV.fetch('DATABASE_URL')).to eq('postgresql://from-the-container')
    end
  end
end
