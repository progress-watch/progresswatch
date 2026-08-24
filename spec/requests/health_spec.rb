# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health' do
  it 'reports every dependency it checks' do
    get '/up'

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('status' => 'ok', 'database' => true, 'redis' => true)
    expect(response.parsed_body).to have_key('worker')
  end

  it 'fails when a dependency the request needs is down' do
    allow(ProgressWatch::PROGRESS_REDIS).to receive(:with).and_raise(Redis::CannotConnectError)

    get '/up'

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to include('status' => 'error', 'redis' => false)
  end

  # A server whose worker is dead answers every request and quietly never notifies anyone.
  # It is the failure the self-hosting page warns about, and this is where it becomes
  # visible — but pulling the web container out of rotation over it would fix nothing.
  it 'says the worker is down without failing the check' do
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([])

    get '/up'

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('status' => 'ok', 'worker' => false)
  end

  it 'reports the worker as down rather than raising when its Redis is unreachable' do
    allow(Sidekiq::ProcessSet).to receive(:new).and_raise(Redis::CannotConnectError)

    get '/up'

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('worker' => false)
  end
end
