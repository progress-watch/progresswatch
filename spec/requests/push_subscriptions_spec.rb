# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Push subscriptions' do
  let(:space) { create_space }
  let(:subscription) do
    { endpoint: 'https://push.example.com/abc', p256dh: 'key', auth: 'secret' }
  end

  def subscribe(attributes = subscription)
    post space_push_path(space.uuid), params: { subscription: attributes }, as: :json
  end

  it 'registers a browser for one space' do
    expect { subscribe }.to change(PushSubscription, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(space.push_subscriptions.first).to have_attributes(endpoint: subscription[:endpoint], auth: 'secret')
  end

  it 'replaces a row rather than adding one when the same endpoint returns' do
    subscribe

    expect { subscribe(subscription.merge(p256dh: 'rotated')) }.not_to change(PushSubscription, :count)
    expect(space.push_subscriptions.first.p256dh).to eq('rotated')
  end

  it 'keeps the same endpoint in two spaces apart' do
    other = create_space

    subscribe
    post space_push_path(other.uuid), params: { subscription: subscription }, as: :json

    expect(PushSubscription.count).to eq(2)
  end

  it 'removes the registration by endpoint' do
    subscribe

    expect { delete space_push_path(space.uuid), params: { endpoint: subscription[:endpoint] }, as: :json }
      .to change(PushSubscription, :count).by(-1)

    expect(response).to have_http_status(:no_content)
  end

  it 'answers the not-found page for a space that does not exist' do
    post space_push_path(SecureRandom.uuid), params: { subscription: subscription }, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'goes away with the space' do
    subscribe

    expect { space.destroy }.to change(PushSubscription, :count).by(-1)
  end
end
