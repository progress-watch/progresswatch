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

    it '404s for an unknown space' do
      get "/spaces/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
      expect(json['error']).to be_present
    end
  end
end
