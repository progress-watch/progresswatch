# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App links' do
  before { stub_const('ProgressWatch::IOS_APP_ID', 'TEAMID1234.example.app') }

  it 'hands a space page to the app it names, as JSON with no extension and no redirect' do
    get '/.well-known/apple-app-site-association'

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('application/json')

    details = json.dig('applinks', 'details')
    expect(details.pluck('appIDs')).to eq([['TEAMID1234.example.app']])
    expect(details.first['components']).to eq([{ '/' => '/s/????????-????-????-????-????????????' }])
  end

  it 'claims a space and nothing under it or beside it' do
    pattern = %r{\A/s/[^/]{8}-[^/]{4}-[^/]{4}-[^/]{4}-[^/]{12}\z}
    space = create_space

    expect("/s/#{space.uuid}").to match(pattern)
    ["/s/#{space.uuid}/edit", "/s/#{space.uuid}/link", '/s/new', '/docs'].each do |path|
      expect(path).not_to match(pattern)
    end
  end

  it 'is not served at all when no app is named, which is the default' do
    stub_const('ProgressWatch::IOS_APP_ID', nil)

    get '/.well-known/apple-app-site-association'

    expect(response).to have_http_status(:not_found)
  end
end
