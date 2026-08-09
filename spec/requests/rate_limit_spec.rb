# frozen_string_literal: true

require 'rails_helper'

# The number is the switch: unset, none of this exists, which is what a self-hoster gets
# and what every other spec in the suite runs under.
RSpec.describe 'Rate limiting' do
  def with_limit(number)
    stub_const('RateLimit::PER_HOUR', number)
    yield
  ensure
    ProgressWatch::PROGRESS_REDIS.with { |redis| redis.del(redis.keys("#{RateLimit::KEY_PREFIX}:*")) }
  end

  it 'is off when the variable is unset, however many spaces are created' do
    5.times { post '/spaces' }

    expect(response).to have_http_status(:created)
  end

  it 'answers 429 once an address is past the number' do
    with_limit(2) do
      2.times { post '/spaces' }
      expect(response).to have_http_status(:created)

      post '/spaces'

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body['error']).to include('Too many')
    end
  end

  # The hour is public; where this address sits inside its hour is not. Retry-After would
  # turn a blind retry into a schedule.
  it 'names the window without saying where in it you are' do
    with_limit(1) do
      post '/spaces'
      post '/spaces'

      expect(response.headers['Retry-After']).to be_nil
      expect(response.parsed_body['error']).to include('within the hour')
    end
  end

  # One budget covers both, because both are a row that outlives the request.
  it 'counts tasks against the same budget as spaces' do
    space = create_space

    with_limit(1) do
      post "/spaces/#{space.uuid}/tasks", params: { title: 'One' }
      expect(response).to have_http_status(:created)

      post '/spaces'

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  # Reporting is the call a crawler makes every second, and it writes to Redis under a
  # TTL. Limiting it would break the product to protect nothing.
  it 'never limits reporting progress' do
    task = create_task(create_space)

    with_limit(1) do
      post '/spaces'

      5.times { put "/tasks/#{task.uuid}", params: { current: 1, end: 10 } }

      expect(response).to have_http_status(:ok)
    end
  end

  it 'limits creating over MCP, and leaves the other tools alone' do
    space = create_space

    with_limit(1) do
      post "/mcp/#{space.uuid}", params: mcp_call('create_task', title: 'One'), as: :json
      expect(response).to have_http_status(:ok)

      post "/mcp/#{space.uuid}", params: mcp_call('create_task', title: 'Two'), as: :json
      expect(response).to have_http_status(:too_many_requests)

      post "/mcp/#{space.uuid}", params: mcp_call('update_task', task_uuid: create_task(space).uuid, current: 1),
                                 as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  def mcp_call(name, arguments)
    { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name:, arguments: } }
  end
end
