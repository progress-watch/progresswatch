# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Push relay' do
  let(:apns) { instance_double(PushDelivery::Apns, push: :ok) }
  let(:phone) { { service: 'apns', token: 'ef' * 32, environment: 'production', subscription: SecureRandom.uuid } }
  let(:tablet) { { service: 'apns', token: 'ab' * 32, environment: 'sandbox', subscription: SecureRandom.uuid } }
  let(:notification) do
    { title: 'Crawl docs', body: 'Crawl docs completed', tag: SecureRandom.uuid, devices: [phone] }
  end

  def relay(body = notification)
    post '/relay', params: body, as: :json
  end

  it 'does not exist on a server with no key for the app' do
    relay

    expect(response).to have_http_status(:not_found)
  end

  context 'with a key for the app' do
    before do
      allow(ProgressWatch).to receive(:apns?).and_return(true)
      allow(PushDelivery::Apns).to receive(:new).and_return(apns)
    end

    it 'sends one notification to every device it names, and stores nothing' do
      expect { relay(notification.merge(devices: [phone, tablet])) }.not_to change(PushSubscription, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('gone' => [], 'unavailable' => [])
      expect(apns).to have_received(:push).with(
        "https://api.push.apple.com/3/device/#{'ef' * 32}",
        { aps: { alert: { title: 'Crawl docs', body: 'Crawl docs completed' }, 'thread-id': notification[:tag],
                 sound: 'default' }, subscription: phone[:subscription] }
      )
      expect(apns).to have_received(:push).with("https://api.sandbox.push.apple.com/3/device/#{'ab' * 32}",
                                                hash_including(subscription: tablet[:subscription]))
    end

    it 'names the devices Apple no longer knows, so the sender can forget them' do
      allow(apns).to receive(:push).and_return(:ok, :gone)

      relay(notification.merge(devices: [phone, tablet]))

      expect(response.parsed_body['gone']).to eq([tablet[:subscription]])
    end

    it 'hands back the devices of a service it holds no key for, and sends the rest' do
      android = { service: 'fcm', token: 'x' * 40, subscription: SecureRandom.uuid }

      relay(notification.merge(devices: [phone, android]))

      expect(response.parsed_body).to eq('gone' => [], 'unavailable' => [android[:subscription]])
      expect(apns).to have_received(:push).once
    end

    it 'refuses the whole request before sending anything when one device would send the key elsewhere' do
      relay(notification.merge(devices: [phone, tablet.merge(token: 'evil.example.com/steal')]))
      expect(response).to have_http_status(:bad_request)

      relay(notification.except(:body))
      expect(response).to have_http_status(:bad_request)

      relay(notification.except(:devices))
      expect(response).to have_http_status(:bad_request)

      expect(apns).not_to have_received(:push)
    end

    it 'takes no more devices in one request than a sender puts in one' do
      relay(notification.merge(devices: [phone] * (PushDelivery::Relay::BATCH + 1)))

      expect(response).to have_http_status(:bad_request)
      expect(apns).not_to have_received(:push)
    end

    it 'answers 502 when Apple does, so the sender tries again' do
      allow(apns).to receive(:push).and_raise(PushDelivery::Apns::Error)

      relay

      expect(response).to have_http_status(:bad_gateway)
    end

    it 'counts a notification against the limit, not the devices it goes to, apart from creating spaces' do
      stub_const('RateLimit::PER_HOUR', 1)

      relay(notification.merge(devices: [phone, tablet]))
      expect(response).to have_http_status(:ok)

      relay
      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body['error']).to include('notifications relayed')

      post '/spaces', params: {}, as: :json
      expect(response).to have_http_status(:created)
    end
  end
end
