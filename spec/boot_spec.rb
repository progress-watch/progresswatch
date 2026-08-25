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

  it 'boots with Web Push configured, and uses that backend' do
    output, ok = boot('VAPID_PUBLIC_KEY' => 'public', 'VAPID_PRIVATE_KEY' => 'private')

    expect(ok).to be(true), output
    expect(output).to include('PushDelivery::WebPush')
  end

  it 'boots without it, and notifies nowhere' do
    output, ok = boot('VAPID_PUBLIC_KEY' => '', 'VAPID_PRIVATE_KEY' => '')

    expect(ok).to be(true), output
    expect(output).to include('PushDelivery::Log')
  end
end
