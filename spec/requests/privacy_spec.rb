# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Privacy policy' do
  let(:app_headers) { { 'User-Agent' => 'Progress Watch iOS/0.0.1 Hotwire Native iOS; Turbo Native iOS;' } }

  def hosted!
    allow(ProgressWatch).to receive(:multitenant?).and_return(true)
  end

  it 'belongs to the hosted service, and a self-hosted server has none to show or to link' do
    get '/privacy'
    expect(response).to have_http_status(:not_found)

    ['/', '/docs'].each do |path|
      get path
      expect(response.body).not_to include('href="/privacy"'), "#{path} links a page that is not there"
    end

    get '/', headers: app_headers
    expect(response.body).not_to include('href="/privacy"')
  end

  it 'is one English page that may be indexed, whatever language the reader has chosen' do
    hosted!

    get '/privacy', headers: { 'Accept-Language' => 'de' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<title>Privacy Policy | Progress Watch</title>', '<article lang="en">')
    expect(response.body).to include('<link rel="canonical" href="http://www.example.com/privacy">')
    expect(response.body).not_to include('name="robots"', 'hreflang')
  end

  it 'says what the server really does: the day of progress, the month for an empty space, the relay' do
    hosted!

    get '/privacy'

    expect(response.body).to include('expire 24 hours after the last report')
    expect(response.body).to include("once it is #{Spaces::SweepEmpty::EMPTY_FOR.in_days.to_i} days old")
    expect(response.body).to include('We forward it to Apple and do not store it')
    expect(response.body).to include('mailto:hi@progress.watch')
  end

  it 'is linked from the phone menu, the documentation sidebar and the list menu of the app' do
    hosted!

    get '/docs'
    expect(response.body.scan('href="/privacy"').size).to eq(2)

    get '/', headers: app_headers
    expect(response.body).to match(%r{data-placement="menu" data-icon="shield">\s*<a href="/privacy">Privacy</a>})

    get '/privacy', headers: app_headers
    expect(response.body).to include('<title>Privacy</title>')
  end
end
