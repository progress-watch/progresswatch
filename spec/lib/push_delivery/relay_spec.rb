# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PushDelivery::Relay do
  let(:space) { create_space }
  let(:root) { SecureRandom.uuid }
  let(:payload) do
    { space_uuid: space.uuid, task_uuid: root, root_uuid: root, tag: root, renotify: true,
      title: 'Crawl docs', body: 'Crawl docs completed', duration: 12 }
  end
  let!(:phone) { register('cd' * 32, 'production') }
  let!(:tablet) { register('ab' * 32, 'sandbox') }

  def register(token, environment)
    PushSubscriptions::Create.call(space:, endpoint: PushDelivery::Apns.endpoint(token:, environment:))
  end

  def answer(code, gone: [], unavailable: [])
    instance_double(Net::HTTPResponse, code: code.to_s, body: { gone:, unavailable: }.to_json)
  end

  def deliver
    PushDelivery::Subscribers.new.call(payload)
  end

  it 'hands one notification for every device in the space to the hosted service, without the space uuid' do
    sent = []
    allow(Net::HTTP).to receive(:post) { |uri, body, _headers| (sent << [uri.to_s, JSON.parse(body)]) && answer(200) }

    deliver

    expect(sent.size).to eq(1)
    url, body = sent.first
    expect(url).to eq('https://progress.watch/relay')
    expect(body.except('devices')).to eq('title' => 'Crawl docs', 'body' => 'Crawl docs completed', 'tag' => root,
                                         'sound' => true)
    expect(body['devices']).to contain_exactly(
      { 'service' => 'apns', 'token' => 'cd' * 32, 'environment' => 'production', 'subscription' => phone.uuid },
      { 'service' => 'apns', 'token' => 'ab' * 32, 'environment' => 'sandbox', 'subscription' => tablet.uuid }
    )
    expect(body.to_json).not_to include(space.uuid)
  end

  it 'sends an Android device in the same request, by its own service and with no environment' do
    token = "fcm-token:#{'a' * 40}"
    android = PushSubscriptions::Create.call(space:, endpoint: PushDelivery::Fcm.endpoint(token:))
    sent = nil
    allow(Net::HTTP).to receive(:post) { |_uri, body, _headers| (sent = JSON.parse(body)) && answer(200) }

    deliver

    expect(Net::HTTP).to have_received(:post).once
    expect(sent['devices']).to include(
      { 'service' => 'fcm', 'token' => token, 'subscription' => android.uuid }
    )
  end

  it 'never hands an Android device to Web Push, and sends it nowhere where there is no relay' do
    web_push = instance_double(PushDelivery::WebPush, deliver: nil)
    allow(ProgressWatch).to receive_messages(web_push?: true, multitenant?: true)
    allow(PushDelivery::WebPush).to receive(:new).and_return(web_push)
    allow(Net::HTTP).to receive(:post)
    PushSubscriptions::Create.call(space:, endpoint: PushDelivery::Fcm.endpoint(token: 'b' * 40))

    deliver

    expect(web_push).not_to have_received(:deliver)
    expect(Net::HTTP).not_to have_received(:post)
  end

  it 'splits a space watched by more devices than one request takes' do
    stub_const('PushDelivery::Relay::BATCH', 1)
    allow(Net::HTTP).to receive(:post).and_return(answer(200))

    deliver

    expect(Net::HTTP).to have_received(:post).twice
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

    expect(apns).to have_received(:deliver).with(phone, payload)
    expect(apns).to have_received(:deliver).with(tablet, payload)
    expect(Net::HTTP).not_to have_received(:post)
  end

  it 'is not used by the hosted service, which would be relaying to itself' do
    allow(ProgressWatch).to receive(:multitenant?).and_return(true)

    expect(ProgressWatch.push_relay?).to be(false)
    expect(ProgressWatch.native_push?).to be(false)
  end

  it 'drops the registrations the relay says Apple no longer knows, and only those' do
    allow(Net::HTTP).to receive(:post).and_return(answer(200, gone: [tablet.uuid]))

    expect { deliver }.to change(PushSubscription, :count).by(-1)
    expect(PushSubscription.exists?(phone.uuid)).to be(true)
  end

  it 'keeps the registrations and says so when the relay relays nothing, or not to some of them' do
    allow(Rails.logger).to receive(:warn)

    allow(Net::HTTP).to receive(:post).and_return(answer(404))
    expect { deliver }.not_to change(PushSubscription, :count)

    allow(Net::HTTP).to receive(:post).and_return(answer(200, unavailable: [phone.uuid]))
    expect { deliver }.not_to change(PushSubscription, :count)

    expect(Rails.logger).to have_received(:warn).with(/"event":"push.relay_unavailable"/).twice
  end

  it 'lets any other answer reach Sidekiq, which retries' do
    allow(Net::HTTP).to receive(:post).and_return(answer(502))

    expect { deliver }.to raise_error(described_class::Error)
  end
end
