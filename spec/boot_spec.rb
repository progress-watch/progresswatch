# frozen_string_literal: true

require 'rails_helper'
require 'open3'

# The suite runs inside an already-booted app, so nothing in it can see a failure that
# happens while Rails initializes. This one boots a second process to look.
#
# It exists because wiring the push backend from an initializer raised — PushDelivery is
# autoloaded from lib, and autoloading during initialization is not allowed — and the
# raise only happened once VAPID keys were set. Every other spec passed; the container
# restart-looped in production.
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
