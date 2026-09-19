# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'APNs relay' do
  let(:apns) { instance_double(PushDelivery::Apns, push: :ok) }
  let(:notification) do
    { token: 'ef' * 32, environment: 'production', title: 'Crawl docs', body: 'Crawl docs completed',
      tag: SecureRandom.uuid, subscription: SecureRandom.uuid }
  end

  def relay(body = notification)
    post '/relay/apns', params: body, as: :json
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

    it 'forwards the notification to the device it names, and stores nothing' do
      expect { relay }.not_to change(PushSubscription, :count)

      expect(response).to have_http_status(:no_content)
      expect(apns).to have_received(:push).with(
        "https://api.push.apple.com/3/device/#{'ef' * 32}",
        { aps: { alert: { title: 'Crawl docs', body: 'Crawl docs completed' }, 'thread-id': notification[:tag],
                 sound: 'default' }, subscription: notification[:subscription] }
      )
    end

    it 'passes on that Apple no longer knows the device' do
      allow(apns).to receive(:push).and_return(:gone)

      relay

      expect(response).to have_http_status(:gone)
    end

    it 'refuses a token that would send the key somewhere else, and a body with nothing to say' do
      relay(notification.merge(token: 'evil.example.com/steal'))
      expect(response).to have_http_status(:bad_request)

      relay(notification.except(:body))
      expect(response).to have_http_status(:bad_request)

      expect(apns).not_to have_received(:push)
    end

    it 'answers 502 when Apple does, so the sender tries again' do
      allow(apns).to receive(:push).and_raise(PushDelivery::Apns::Error)

      relay

      expect(response).to have_http_status(:bad_gateway)
    end

    it 'is rate limited by address, apart from creating spaces and tasks' do
      stub_const('RateLimit::PER_HOUR', 1)

      relay
      relay

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body['error']).to include('notifications relayed')

      post '/spaces', params: {}, as: :json
      expect(response).to have_http_status(:created)
    end
  end
end
