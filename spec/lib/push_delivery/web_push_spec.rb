# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PushDelivery::WebPush do
  let(:space) { create_space }
  let(:root) { SecureRandom.uuid }
  let(:payload) do
    { space_uuid: space.uuid, task_uuid: root, root_uuid: root, tag: root, renotify: true,
      title: 'Crawl docs', body: 'Crawl docs completed', duration: 12 }
  end

  before do
    stub_const('ProgressWatch::VAPID_PUBLIC_KEY', 'public')
    stub_const('ProgressWatch::VAPID_PRIVATE_KEY', 'private')
    PushSubscriptions::Create.call(space:, endpoint: 'https://push.example.com/a', p256dh: 'k', auth: 's')
  end

  it 'sends to every browser registered on the space, and to no other space' do
    PushSubscriptions::Create.call(space: create_space, endpoint: 'https://push.example.com/b',
                                   p256dh: 'k', auth: 's')
    sent = []
    allow(WebPush).to receive(:payload_send) { |args| sent << args }

    described_class.new.call(payload)

    expect(sent.size).to eq(1)
    expect(sent.first[:endpoint]).to eq('https://push.example.com/a')
    expect(JSON.parse(sent.first[:message]))
      .to include('title' => 'Crawl docs', 'url' => "/s/#{space.uuid}", 'tag' => root, 'renotify' => true)
  end

  # Deleting the row is right and it is also the end of the trail: the browser goes on
  # saying it is subscribed, so without this line nothing anywhere records that it stopped.
  it 'drops a registration the push service says is gone, and says so' do
    allow(WebPush).to receive(:payload_send).and_raise(gone(410))
    allow(Rails.logger).to receive(:warn)

    expect { described_class.new.call(payload) }.to change(PushSubscription, :count).by(-1)
    expect(Rails.logger).to have_received(:warn).with(/"event":"push.gone".*"code":410/)
  end

  it 'lets any other failure reach Sidekiq, which retries' do
    allow(WebPush).to receive(:payload_send).and_raise(gone(503))

    expect { described_class.new.call(payload) }.to raise_error(WebPush::ResponseError)
    expect(PushSubscription.count).to eq(1)
  end

  def gone(code)
    WebPush::ResponseError.new(instance_double(Net::HTTPResponse, code: code.to_s, message: '', body: ''), 'host')
  end
end
