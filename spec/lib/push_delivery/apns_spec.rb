# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PushDelivery::Apns do
  let(:space) { create_space }
  let(:root) { SecureRandom.uuid }
  let(:token) { 'ab' * 32 }
  let(:key) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:session) { instance_double(HTTPX::Session) }
  let(:payload) do
    { space_uuid: space.uuid, task_uuid: root, root_uuid: root, tag: root, renotify: true,
      title: 'Crawl docs', body: 'Crawl docs completed', duration: 12 }
  end
  let!(:subscription) do
    PushSubscriptions::Create.call(space:, endpoint: described_class.endpoint(token:, environment: 'sandbox'))
  end

  before do
    stub_const('ProgressWatch::APNS_KEY', key.to_pem)
    stub_const('ProgressWatch::APNS_KEY_ID', 'KEYID12345')
    stub_const('ProgressWatch::APNS_TEAM_ID', 'TEAMID1234')
    described_class.instance_variable_set(:@authorization, nil)
    allow(HTTPX).to receive(:with).and_return(session)
  end

  def answer(status, body = '')
    instance_double(HTTPX::Response, status:, body:)
  end

  def deliver
    PushDelivery::Subscribers.new.call(payload)
  end

  describe '.endpoint' do
    it 'points at Apple and nowhere a client could name' do
      expect(described_class.endpoint(token: token.upcase, environment: 'production'))
        .to eq("https://api.push.apple.com/3/device/#{token}")
      expect(subscription.endpoint).to start_with('https://api.sandbox.push.apple.com/3/device/')
    end

    it 'refuses anything that is not a device token or a known environment' do
      expect { described_class.endpoint(token: 'evil.example.com/x', environment: 'production') }
        .to raise_error(described_class::InvalidDevice)
      expect { described_class.endpoint(token:, environment: 'evil.example.com') }
        .to raise_error(described_class::InvalidDevice)
    end
  end

  it 'signs the request for the app, collapses by job, and keeps the space uuid out of what Apple reads' do
    sent = nil
    allow(session).to receive(:post) { |url, json:| (sent = [url, json]) && answer(200) }

    deliver

    headers = nil
    expect(HTTPX).to have_received(:with) { |options| headers = options[:headers] }
    claims, header = JWT.decode(headers['authorization'].delete_prefix('bearer '), key, true, algorithm: 'ES256')

    expect(sent.first).to eq(subscription.endpoint)
    expect(sent.last).to eq(aps: { alert: { title: 'Crawl docs', body: 'Crawl docs completed' }, 'thread-id': root,
                                   sound: 'default' }, subscription: subscription.uuid)
    expect(sent.last.to_json).not_to include(space.uuid)
    expect(headers).to include('apns-topic' => 'watch.progress.app', 'apns-push-type' => 'alert',
                               'apns-collapse-id' => root)
    expect([claims['iss'], header['kid']]).to eq(%w[TEAMID1234 KEYID12345])
  end

  it 'is silent for a step, which only replaces its job on the screen' do
    sent = nil
    allow(session).to receive(:post) { |_url, json:| (sent = json) && answer(200) }

    PushDelivery::Subscribers.new.call(payload.merge(renotify: false))

    expect(sent[:aps]).not_to have_key(:sound)
  end

  it 'drops a registration Apple no longer knows, by status or by reason' do
    allow(Rails.logger).to receive(:warn)
    allow(session).to receive(:post).and_return(answer(400, '{"reason":"BadDeviceToken"}'))

    expect { deliver }.to change(PushSubscription, :count).by(-1)
    expect(Rails.logger).to have_received(:warn).with(/"event":"push.gone"/)
  end

  it 'lets any other answer reach Sidekiq, which retries' do
    allow(session).to receive(:post).and_return(answer(503, '{"reason":"ServiceUnavailable"}'))

    expect { deliver }.to raise_error(described_class::Error, /503 ServiceUnavailable/)
    expect(PushSubscription.count).to eq(1)
  end
end
