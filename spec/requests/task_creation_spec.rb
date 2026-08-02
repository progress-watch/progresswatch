# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Task creation' do
  let(:space) { create_space }

  it 'returns the uuid of the new task' do
    post_json "/spaces/#{space.uuid}/tasks", { title: 'Crawl', source: 'crawler.py' }

    expect(response).to have_http_status(:created)
    task = Task.find(json['uuid'])
    expect(task.title).to eq('Crawl')
    expect(task.source).to eq('crawler.py')
  end

  it 'creates a child under a top-level task' do
    parent = create_task(space, title: 'Deploy')

    post_json "/spaces/#{space.uuid}/tasks", { title: 'Build', parent_uuid: parent.uuid }

    expect(response).to have_http_status(:created)
    expect(Task.find(json['uuid']).parent_uuid).to eq(parent.uuid)
  end

  describe 'nesting is one level only' do
    it 'rejects a parent_uuid pointing at a task that is already a child' do
      parent = create_task(space, title: 'Deploy')
      child = create_task(space, title: 'Build', parent_uuid: parent.uuid)

      post_json "/spaces/#{space.uuid}/tasks", { title: 'Compile', parent_uuid: child.uuid }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['error']).to include('one level only')
      expect(Task.where(parent_uuid: child.uuid)).to be_empty
    end

    it 'rejects a parent_uuid that does not exist' do
      post_json "/spaces/#{space.uuid}/tasks", { title: 'Build', parent_uuid: SecureRandom.uuid }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['error']).to include('known task')
    end

    it 'rejects a parent in a different space' do
      foreign_parent = create_task(create_space(title: 'Other'), title: 'Elsewhere')

      post_json "/spaces/#{space.uuid}/tasks", { title: 'Build', parent_uuid: foreign_parent.uuid }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['error']).to include('different space')
    end
  end

  it '404s for an unknown space' do
    post_json "/spaces/#{SecureRandom.uuid}/tasks", { title: 'Crawl' }

    expect(response).to have_http_status(:not_found)
  end
end
