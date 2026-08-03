# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Installable to the home screen' do
  it 'serves a manifest naming icons that exist' do
    manifest = JSON.parse(Rails.public_path.join('manifest.json').read)

    expect(manifest).to include('name' => 'Progress Watch', 'display' => 'standalone', 'start_url' => '/')

    manifest['icons'].each do |icon|
      expect(Rails.public_path.join(icon['src'].delete_prefix('/'))).to exist
    end
  end

  it 'links the manifest and an apple-touch-icon from every page' do
    get '/about'

    expect(response.body).to include('<link rel="manifest" href="/manifest.json">')
    expect(response.body).to include('<link rel="apple-touch-icon" href="/icons/icon-180.png">')
    expect(response.body).to include('<meta name="apple-mobile-web-app-capable" content="yes">')
  end

  it 'ships the service worker at the root, so its scope is the whole app' do
    expect(Rails.public_path.join('sw.js').read).to include('showNotification')
  end
end
