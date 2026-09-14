# frozen_string_literal: true

require 'rails_helper'
require 'aws-sdk-secretsmanager'
require 'tmpdir'

RSpec.describe 'Dotenv' do
  let(:workdir) { Dir.mktmpdir }
  let(:dotenv) { File.join(workdir, 'progresswatch.env') }

  after { FileUtils.remove_entry(workdir) }

  def boot(values = {})
    environment = ENV.to_h.except('SECRET_KEY_BASE', 'DATABASE_URL', 'REDIS_URL', 'LOCAL_REDIS_URL',
                                  'AWS_SECRET_MANAGER_ID')
    stub_const('ENV', environment.merge('RAILS_ENV' => 'production', 'WORKDIR' => workdir).merge(values))
    load Rails.root.join('config/dotenv.rb').to_s
  end

  it 'does nothing outside production' do
    boot('RAILS_ENV' => 'test')

    expect(ENV.fetch('REDIS_URL', nil)).to be_nil
    expect(File).not_to exist(dotenv)
  end

  it 'generates a secret key on the volume that nobody else can read, and reads it back after' do
    boot

    key = ENV.fetch('SECRET_KEY_BASE')
    expect(key).to match(/\A\h{128}\z/)
    expect(File.stat(dotenv).mode & 0o777).to eq(0o600)
    expect(ENV.fetch('DATABASE_URL', nil)).to be_nil

    boot

    expect(ENV.fetch('SECRET_KEY_BASE')).to eq(key)
  end

  it 'takes DATABASE_URL from the file once somebody fills it in' do
    boot
    File.write(dotenv, File.read(dotenv).sub(/^DATABASE_URL=.*$/, 'DATABASE_URL=postgresql://from-the-file'))

    boot

    expect(ENV.fetch('DATABASE_URL')).to eq('postgresql://from-the-file')
  end

  it 'leaves a key from the environment alone and writes nothing' do
    boot('SECRET_KEY_BASE' => 'from-the-container')

    expect(ENV.fetch('SECRET_KEY_BASE')).to eq('from-the-container')
    expect(File).not_to exist(dotenv)
  end

  it 'points REDIS_URL at the Redis inside, with a password derived from the key' do
    boot('SECRET_KEY_BASE' => 'from-the-container')

    password = Digest::SHA1.hexdigest('redisfrom-the-container')
    expect(ENV.fetch('REDIS_URL')).to eq("redis://default:#{password}@127.0.0.1:16379/0")
    expect(ENV.fetch('LOCAL_REDIS_URL')).to eq(ENV.fetch('REDIS_URL'))
  end

  it 'starts no Redis inside when REDIS_URL is set' do
    boot('SECRET_KEY_BASE' => 'from-the-container', 'REDIS_URL' => 'redis://elsewhere:6379')

    expect(ENV.fetch('REDIS_URL')).to eq('redis://elsewhere:6379')
    expect(ENV.fetch('LOCAL_REDIS_URL', nil)).to be_nil
  end

  context 'with a secret in AWS' do
    let(:client) { instance_double(Aws::SecretsManager::Client) }
    let(:secret) do
      { 'SECRET_KEY_BASE' => 'from-aws', 'REDIS_URL' => 'redis://127.0.0.1:6379', 'WEB_CONCURRENCY' => 2 }
    end

    before do
      allow(Aws::SecretsManager::Client).to receive(:new).and_return(client)
      allow(client).to receive(:get_secret_value).with(secret_id: '/progresswatch/production')
                                                 .and_return(instance_double(
                                                               Aws::SecretsManager::Types::GetSecretValueResponse,
                                                               secret_string: secret.to_json
                                                             ))
    end

    it 'puts every key into ENV as a string, and generates nothing' do
      boot('AWS_SECRET_MANAGER_ID' => '/progresswatch/production')

      expect(ENV.fetch('SECRET_KEY_BASE')).to eq('from-aws')
      expect(ENV.fetch('WEB_CONCURRENCY')).to eq('2')
      expect(ENV.fetch('LOCAL_REDIS_URL', nil)).to be_nil
      expect(File).not_to exist(dotenv)
    end

    it 'leaves a value already in the environment alone' do
      boot('AWS_SECRET_MANAGER_ID' => '/progresswatch/production', 'REDIS_URL' => 'redis://from-the-container')

      expect(ENV.fetch('REDIS_URL')).to eq('redis://from-the-container')
    end
  end
end
