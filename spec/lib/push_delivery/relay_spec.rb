# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PushDelivery::Relay do
  let(:space) { create_space }
  let(:root) { SecureRandom.uuid }
  let(:token) { 'cd' * 32 }
  let(:payload) do
    { space_uuid: space.uuid, task_uuid: root, root_uuid: root, tag: root, renotify: true,
      title: 'Crawl docs', body: 'Crawl docs completed', duration: 12 }
  end
  let!(:subscription) do
    PushSubscriptions::Create.call(space:, endpoint: PushDelivery::Apns.endpoint(token:, environment: 'production'))
  end

  def answer(code)
    instance_double(Net::HTTPResponse, code: code.to_s)
  end

  def deliver
    PushDelivery::Subscribers.new.call(payload)
  end

  it 'hands the notification to the hosted service, without the space uuid' do
    sent = nil
    allow(Net::HTTP).to receive(:post) { |uri, body, _headers| (sent = [uri.to_s, JSON.parse(body)]) && answer(204) }

    deliver

    expect(sent.first).to eq('https://progress.watch/relay/apns')
    expect(sent.last).to eq('token' => token, 'environment' => 'production', 'title' => 'Crawl docs',
                            'body' => 'Crawl docs completed', 'tag' => root, 'sound' => true,
                            'subscription' => subscription.uuid)
    expect(sent.last.to_json).not_to include(space.uuid)
  end

  it 'is not used when the server is told not to' do
    allow(Net::HTTP).to receive(:post)

    stub_const('ProgressWatch::PUSH_RELAY', 'false')
    deliver

    expect(Net::HTTP).not_to have_received(:post)
    expect(ProgressWatch.native_push?).to be(false)
  end

  it 'is not used once the server holds a key of its own' do
    apns = instance_double(PushDelivery::Apns, deliver: nil)
    allow(ProgressWatch).to receive(:apns?).and_return(true)
    allow(PushDelivery::Apns).to receive(:new).and_return(apns)
    allow(Net::HTTP).to receive(:post)

    deliver

    expect(apns).to have_received(:deliver).with(subscription, payload)
    expect(Net::HTTP).not_to have_received(:post)
  end

  it 'is not used by the hosted service, which would be relaying to itself' do
    allow(ProgressWatch).to receive(:multitenant?).and_return(true)

    expect(ProgressWatch.push_relay?).to be(false)
    expect(ProgressWatch.native_push?).to be(false)
  end

  it 'drops a registration the relay says Apple no longer knows' do
    allow(Net::HTTP).to receive(:post).and_return(answer(410))

    expect { deliver }.to change(PushSubscription, :count).by(-1)
  end

  it 'keeps the registration and says so when the relay relays nothing' do
    allow(Net::HTTP).to receive(:post).and_return(answer(404))
    allow(Rails.logger).to receive(:warn)

    expect { deliver }.not_to change(PushSubscription, :count)
    expect(Rails.logger).to have_received(:warn).with(/"event":"push.relay_unavailable"/)
  end

  it 'lets any other answer reach Sidekiq, which retries' do
    allow(Net::HTTP).to receive(:post).and_return(answer(502))

    expect { deliver }.to raise_error(described_class::Error)
  end
end
