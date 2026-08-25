# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Spaces' do
  describe 'POST /spaces' do
    it 'creates a space and returns its uuid' do
      post_json '/spaces', { title: 'Production' }

      expect(response).to have_http_status(:created)
      expect(json['uuid']).to match(/\A[0-9a-f-]{36}\z/)
      expect(json['title']).to eq('Production')
    end

    it 'creates a space without a title' do
      post_json '/spaces', {}

      expect(response).to have_http_status(:created)
      expect(Space.find(json['uuid'])).to be_present
    end

    it 'accepts a one-character icon' do
      post_json '/spaces', { title: 'Nightly', icon: '🌙' }

      expect(response).to have_http_status(:created)
      expect(json['icon']).to eq('🌙')
    end

    it 'takes a multi-codepoint emoji as one character and refuses two of anything' do
      post_json '/spaces', { title: 'Team', icon: '👍🏽' }
      expect(response).to have_http_status(:created)

      post_json '/spaces', { title: 'Nope', icon: 'ab' }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET /spaces/:space_uuid' do
    it 'returns top-level tasks with children nested underneath' do
      space = create_space
      parent = create_task(space, title: 'Deploy')
      child = create_task(space, title: 'Build', parent_uuid: parent.uuid)
      other = create_task(space, title: 'Backup')

      get "/spaces/#{space.uuid}"

      expect(response).to have_http_status(:ok)
      expect(json['tasks'].pluck('uuid')).to contain_exactly(parent.uuid, other.uuid)

      rendered_parent = json['tasks'].find { |t| t['uuid'] == parent.uuid }
      expect(rendered_parent['children'].pluck('uuid')).to eq([child.uuid])
    end

    it 'returns every task when no window is asked for' do
      space = create_space
      3.times { |index| create_task(space, title: "Task #{index}") }

      get "/spaces/#{space.uuid}"

      expect(json['tasks'].pluck('title')).to eq(['Task 0', 'Task 1', 'Task 2'])
    end

    it 'takes the newest when given a bare limit' do
      space = create_space
      3.times { |index| create_task(space, title: "Task #{index}") }

      get "/spaces/#{space.uuid}", params: { limit: 2 }

      expect(json['tasks'].pluck('title')).to eq(['Task 1', 'Task 2'])
    end

    it 'pages both ways from a timestamp it returned itself' do
      space = create_space
      3.times { |index| create_task(space, title: "Task #{index}") }

      get "/spaces/#{space.uuid}"
      middle = json['tasks'][1]['created_at']

      get "/spaces/#{space.uuid}", params: { before: middle }
      expect(json['tasks'].pluck('title')).to eq(['Task 0'])

      get "/spaces/#{space.uuid}", params: { after: middle }
      expect(json['tasks'].pluck('title')).to eq(['Task 2'])
    end

    it '400s on a window it cannot read, rather than quietly returning everything' do
      space = create_space

      get "/spaces/#{space.uuid}", params: { before: 'last tuesday' }

      expect(response).to have_http_status(:bad_request)
      expect(json['error']).to include('ISO 8601')
    end

    it '404s for an unknown space, and says which uuid it could not find' do
      uuid = SecureRandom.uuid

      get "/spaces/#{uuid}"

      expect(response).to have_http_status(:not_found)
      expect(json['error']).to include('Space', uuid)
    end
  end
end
