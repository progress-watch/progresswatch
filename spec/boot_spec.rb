# frozen_string_literal: true

require 'rails_helper'
require 'open3'

RSpec.describe 'Booting' do
  def boot(env)
    output, status = Open3.capture2e(env.merge('RAILS_ENV' => 'test'),
                                     'bin/rails', 'runner', 'puts PushDelivery.backend.class',
                                     chdir: Rails.root.to_s)

    [output, status.success?]
  end

  it 'boots with Web Push configured, and delivers to subscribers' do
    output, ok = boot('VAPID_PUBLIC_KEY' => 'public', 'VAPID_PRIVATE_KEY' => 'private', 'PUSH_RELAY' => 'false')

    expect(ok).to be(true), output
    expect(output).to include('PushDelivery::Subscribers')
  end

  it 'boots with nothing configured, and still delivers to the iOS app through the relay' do
    output, ok = boot('VAPID_PUBLIC_KEY' => '', 'VAPID_PRIVATE_KEY' => '')

    expect(ok).to be(true), output
    expect(output).to include('PushDelivery::Subscribers')
  end

  it 'signs Web Push as the software until an operator names a contact, and never as our mailbox' do
    expect(ProgressWatch::VAPID_SUBJECT).to eq(ProgressWatch::REPOSITORY_URL)

    ours = Rails.root.glob('{app,config,lib}/**/*.rb').select { |path| path.read.include?('@progress.watch') }

    expect(ours).to be_empty
  end

  it 'boots with the relay turned off too, and notifies nowhere' do
    output, ok = boot('VAPID_PUBLIC_KEY' => '', 'VAPID_PRIVATE_KEY' => '', 'PUSH_RELAY' => 'false')

    expect(ok).to be(true), output
    expect(output).to include('PushDelivery::Log')
  end
end
