# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MCP' do
  let(:space) { create_space(title: 'Agent work') }

  def rpc(payload, headers: {}, path: '/mcp')
    post path,
         params: payload.to_json,
         headers: {
           'CONTENT_TYPE' => 'application/json',
           'HTTP_ACCEPT' => 'application/json, text/event-stream',
           'HTTP_X_SPACE_UUID' => space.uuid
         }.merge(headers)
  end

  describe 'initialize' do
    it 'answers with the protocol version, tools capability and server info' do
      rpc({ jsonrpc: '2.0', id: 1, method: 'initialize',
            params: { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'test', version: '1' } } })

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
      expect(json).to include('jsonrpc' => '2.0', 'id' => 1)
      expect(json['result']).to include(
        'protocolVersion' => '2025-06-18',
        'capabilities' => { 'tools' => {} }
      )
      expect(json['result']['serverInfo']['name']).to eq('progress-watch')
    end

    it 'answers a notification with 202 and no body' do
      rpc({ jsonrpc: '2.0', method: 'notifications/initialized' })

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
    end
  end

  describe 'protocol version negotiation' do
    it 'accepts a request with no MCP-Protocol-Version header' do
      rpc({ jsonrpc: '2.0', id: 1, method: 'ping' })

      expect(response).to have_http_status(:ok)
    end

    it 'accepts a supported version' do
      rpc({ jsonrpc: '2.0', id: 1, method: 'ping' }, headers: { 'HTTP_MCP_PROTOCOL_VERSION' => '2025-06-18' })

      expect(response).to have_http_status(:ok)
    end

    it '400s on a version it does not speak' do
      rpc({ jsonrpc: '2.0', id: 1, method: 'ping' }, headers: { 'HTTP_MCP_PROTOCOL_VERSION' => '1999-01-01' })

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'tools/list' do
    it 'lists the tools with input schemas' do
      rpc({ jsonrpc: '2.0', id: 2, method: 'tools/list' })

      names = json['result']['tools'].pluck('name')
      expect(names).to contain_exactly('create_space', 'create_task', 'update_task', 'complete_task')

      json['result']['tools'].each do |tool|
        schema = tool['inputSchema']

        expect(schema['type']).to eq('object')
        expect(tool['description']).to be_present

        # A schema with no required list lets an agent call the tool with {}.
        expect(schema['required']).to be_present
        expect(schema['properties'].keys).to include(*schema['required'])
      end
    end

    it 'tells the agent when tracking is worth it and how nesting behaves' do
      rpc({ jsonrpc: '2.0', id: 2, method: 'tools/list' })

      create = json['result']['tools'].find { |tool| tool['name'] == 'create_task' }
      update = json['result']['tools'].find { |tool| tool['name'] == 'update_task' }

      expect(create['description']).to include('long-running', 'one level only')
      expect(update['description']).to include('replaces the whole state')

      # An agent that reports only at the end leaves a board that is empty for the whole
      # job, which is the thing this exists to prevent.
      expect(create['description']).to include('not all of them at the end')
      expect(update['description']).to include('when the work actually begins')
    end
  end

  describe 'tools/call' do
    def call_tool(name, arguments, **)
      rpc({ jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: name, arguments: arguments } }, **)
    end

    # Not Task.last: the primary key is a random uuid, so it returns an arbitrary row.
    def created_task
      Task.find(json['result']['content'].first['text'][/[0-9a-f-]{36}/])
    end

    it 'creates a task in the space and returns its uuid' do
      expect { call_tool('create_task', { title: 'Refactor auth' }) }.to change(Task, :count).by(1)

      expect(created_task).to have_attributes(space_uuid: space.uuid, title: 'Refactor auth')
    end

    it 'takes the space from the path when no header is given' do
      post "/mcp/#{space.uuid}",
           params: { jsonrpc: '2.0', id: 3, method: 'tools/call',
                     params: { name: 'create_task', arguments: { title: 'From path' } } }.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:ok)
      expect(created_task.space_uuid).to eq(space.uuid)
    end

    it 'reports progress through the same command object as the HTTP API' do
      task = create_task(space, title: 'Crawl')

      call_tool('update_task', { task_uuid: task.uuid, current: 30, end: 100, values: { log: 'working' } })

      state = TaskStates.read(task.uuid)
      expect(state.current).to eq(30)
      expect(state.values).to eq('log' => 'working')
    end

    it 'completes a task and enqueues the notification' do
      task = create_task(space, title: 'Crawl')

      expect do
        call_tool('complete_task', { task_uuid: task.uuid, values: { status: 'succeeded' } })
      end.to have_enqueued_job(CompletionNotificationJob).with(task.uuid)

      expect(task.reload.finished_at).to be_present
    end

    it 'creates a child task under a parent' do
      parent = create_task(space, title: 'Deploy')

      call_tool('create_task', { title: 'Build', parent_uuid: parent.uuid })

      expect(created_task.parent_uuid).to eq(parent.uuid)
    end

    it 'returns a readable isError result when nesting goes two levels deep' do
      parent = create_task(space, title: 'Deploy')
      child = create_task(space, title: 'Build', parent_uuid: parent.uuid)

      call_tool('create_task', { title: 'Compile', parent_uuid: child.uuid })

      expect(response).to have_http_status(:ok)
      expect(json['result']['isError']).to be(true)
      expect(json['result']['content'].first['text']).to include('one level only')
    end

    it 'returns isError for an unknown task rather than a JSON-RPC error' do
      call_tool('update_task', { task_uuid: SecureRandom.uuid, current: 1, end: 2 })

      expect(json['result']['isError']).to be(true)
      expect(json).not_to have_key('error')
    end

    it 'answers an unknown tool with a JSON-RPC error' do
      call_tool('delete_everything', {})

      expect(json['error']['code']).to eq(-32_602)
      expect(json).not_to have_key('result')
    end

    it 'answers an unknown method with method-not-found' do
      rpc({ jsonrpc: '2.0', id: 4, method: 'resources/list' })

      expect(json['error']['code']).to eq(-32_601)
    end

    it 'refuses to create a task with no space configured, and says what to do' do
      rpc({ jsonrpc: '2.0', id: 3, method: 'tools/call',
            params: { name: 'create_task', arguments: { title: 'Orphan' } } },
          headers: { 'HTTP_X_SPACE_UUID' => '' })

      expect(json['error']['code']).to eq(-32_602)
      expect(json['error']['message']).to include('create_space')
    end

    it 'creates a space and hands back the URL the user has to open' do
      space # the let is lazy and rpc touches it, so materialise it before counting

      expect do
        rpc({ jsonrpc: '2.0', id: 3, method: 'tools/call',
              params: { name: 'create_space', arguments: { title: 'Agent bootstrap' } } },
            headers: { 'HTTP_X_SPACE_UUID' => '' })
      end.to change(Space, :count).by(1)

      text = json['result']['content'].first['text']
      created = Space.find(text[/[0-9a-f-]{36}/])

      expect(created.title).to eq('Agent bootstrap')
      expect(text).to include("/s/#{created.uuid}")
    end

    it 'lets a task be created in a space the agent just made, overriding the connection' do
      other = create_space(title: 'Elsewhere')

      call_tool('create_task', { title: 'Over there', space_uuid: other.uuid })

      expect(created_task.space_uuid).to eq(other.uuid)
    end
  end

  describe 'transport' do
    it '405s a GET, since this server opens no server-initiated stream' do
      get '/mcp'

      expect(response).to have_http_status(:method_not_allowed)
    end

    it '400s malformed JSON' do
      post '/mcp', params: 'not json', headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:bad_request)
    end

    # Batching was removed in 2025-06-18; an array is no longer a valid body.
    it '400s a JSON-RPC batch' do
      post '/mcp',
           params: [{ jsonrpc: '2.0', id: 1, method: 'ping' }].to_json,
           headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:bad_request)
      expect(json['error']['code']).to eq(-32_600)
    end

    it 'answers ping with an empty result' do
      rpc({ jsonrpc: '2.0', id: 9, method: 'ping' })

      expect(json['result']).to eq({})
    end
  end
end
