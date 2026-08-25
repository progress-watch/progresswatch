# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Task state' do
  let(:space) { create_space }
  let(:task) { create_task(space, title: 'Crawl') }

  describe 'PUT /tasks/:task_uuid' do
    it 'stores current, end and values' do
      put_json "/tasks/#{task.uuid}", { current: 1200, end: 50_000, values: { pages: 1200, errors: 3 } }

      expect(response).to have_http_status(:ok)
      expect(json['progress']).to include(
        'current' => 1200,
        'end' => 50_000,
        'values' => { 'pages' => 1200, 'errors' => 3 },
        'aggregated' => false
      )
      expect(json['progress']['ratio']).to be_within(0.0001).of(0.024)
    end

    it 'never writes progress to the database' do
      put_json "/tasks/#{task.uuid}", { current: 10, end: 100, values: { log: 'working' } }

      row = ActiveRecord::Base.connection.select_one("SELECT * FROM tasks WHERE uuid = '#{task.uuid}'")
      expect(row.keys).to contain_exactly(
        'uuid', 'space_uuid', 'parent_uuid', 'title', 'source', 'created_at', 'finished_at', 'duration'
      )
    end

    it 'turns PATCH away rather than treating it as a full overwrite' do
      patch "/tasks/#{task.uuid}",
            params: { current: 10, end: 100 }.to_json,
            headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:method_not_allowed)
      expect(json['error']).to include('use PUT')
      expect(TaskStates.read(task.uuid)).to be_nil
    end

    it '404s for an unknown task' do
      put_json "/tasks/#{SecureRandom.uuid}", { current: 1, end: 2 }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'full overwrite semantics' do
    it 'clears stored values when a later request omits them' do
      put_json "/tasks/#{task.uuid}", { current: 10, end: 100, values: { pages: 10, errors: 3 } }
      expect(json['progress']['values']).to eq('pages' => 10, 'errors' => 3)

      put_json "/tasks/#{task.uuid}", { current: 20, end: 100 }

      expect(json['progress']['values']).to eq({})
      expect(TaskStates.read(task.uuid).values).to eq({})
    end

    it 'replaces values wholesale rather than merging keys' do
      put_json "/tasks/#{task.uuid}", { current: 10, end: 100, values: { pages: 10, errors: 3 } }
      put_json "/tasks/#{task.uuid}", { current: 20, end: 100, values: { rate: '45/s' } }

      expect(json['progress']['values']).to eq('rate' => '45/s')
    end

    it 'clears current and end when a later request omits them' do
      put_json "/tasks/#{task.uuid}", { current: 10, end: 100 }
      put_json "/tasks/#{task.uuid}", { values: { log: 'recounting' } }

      expect(json['progress']['current']).to be_nil
      expect(json['progress']['end']).to be_nil
      expect(json['progress']['ratio']).to be_nil
    end

    it 'counts without a total when end is never sent' do
      put_json "/tasks/#{task.uuid}", { current: 1200 }

      expect(json['progress']).to include('current' => 1200, 'end' => nil, 'ratio' => nil)
    end

    it 'accepts end changing mid-flight' do
      put_json "/tasks/#{task.uuid}", { current: 30, end: 100 }
      expect(json['progress']['ratio']).to be_within(0.0001).of(0.3)

      put_json "/tasks/#{task.uuid}", { current: 30, end: 300 }
      expect(json['progress']['ratio']).to be_within(0.0001).of(0.1)
    end
  end

  describe 'values validation' do
    it 'rejects a nested values object' do
      put_json "/tasks/#{task.uuid}", { current: 1, end: 2, values: { nested: { a: 1 } } }

      expect(response).to have_http_status(:bad_request)
      expect(json['error']).to match(/values.nested/)
    end

    it 'rejects a non-numeric current' do
      put_json "/tasks/#{task.uuid}", { current: 'soon', end: 2 }

      expect(response).to have_http_status(:bad_request)
      expect(json['error']).to include('current must be a number')
    end

    it 'accepts numeric strings, which shell scripts produce constantly' do
      put_json "/tasks/#{task.uuid}", { current: '20', end: '100' }

      expect(response).to have_http_status(:ok)
      expect(json['progress']).to include('current' => 20, 'end' => 100)
    end
  end

  describe 'no data is not zero' do
    it 'returns the task with structure intact and progress null when Redis is empty' do
      parent = create_task(space, title: 'Deploy')
      child = create_task(space, title: 'Build', parent_uuid: parent.uuid)

      get "/tasks/#{child.uuid}"

      expect(response).to have_http_status(:ok)
      expect(json['title']).to eq('Build')
      expect(json['parent_uuid']).to eq(parent.uuid)
      expect(json['progress']).to be_nil
    end

    it 'distinguishes a task at zero from a task with no data' do
      reporting = create_task(space, title: 'Reporting')
      put_json "/tasks/#{reporting.uuid}", { current: 0, end: 100 }
      silent = create_task(space, title: 'Silent')

      get "/spaces/#{space.uuid}"

      rendered = json['tasks'].index_by { |t| t['uuid'] }
      expect(rendered[reporting.uuid]['progress']).to include('current' => 0, 'ratio' => 0.0)
      expect(rendered[silent.uuid]['progress']).to be_nil
    end

    it 'survives Redis being flushed underneath a running task' do
      put_json "/tasks/#{task.uuid}", { current: 10, end: 100 }
      ProgressWatch::PROGRESS_REDIS.with(&:flushdb)

      get "/tasks/#{task.uuid}"

      expect(response).to have_http_status(:ok)
      expect(json['title']).to eq('Crawl')
      expect(json['progress']).to be_nil
    end
  end

  describe 'a finished task is complete however it was closed' do
    it 'reports a full ratio for a done with no numbers' do
      put_json "/tasks/#{task.uuid}", { done: true }

      expect(json['progress']).to include('current' => nil, 'end' => nil, 'ratio' => 1.0)
    end

    it 'leaves the counts alone rather than inventing one of one' do
      put_json "/tasks/#{task.uuid}", { current: 3, end: 10, done: true }

      expect(json['progress']).to include('current' => 3, 'end' => 10, 'ratio' => 1.0)
    end

    it 'stays complete after Redis expires' do
      put_json "/tasks/#{task.uuid}", { done: true }
      ProgressWatch::PROGRESS_REDIS.with(&:flushdb)

      get "/tasks/#{task.uuid}"

      expect(json['progress']).to include('ratio' => 1.0)
    end

    it 'still says nothing about an unfinished task that has not reported' do
      get "/tasks/#{task.uuid}"

      expect(json['progress']).to be_nil
    end
  end

  describe 'closing a task without counting' do
    it 'keeps the last numbers it was told' do
      task = create_task(create_space)
      put_json("/tasks/#{task.uuid}", { current: 900, end: 1000, values: { errors: 3 } })

      put_json("/tasks/#{task.uuid}", { done: true })

      expect(json['finished_at']).to be_present
      expect(json['progress']).to include('current' => 900, 'end' => 1000, 'ratio' => 1.0)
      expect(json['progress']['values']).to eq('errors' => 3)
    end

    it 'still reads as complete when there was never anything to keep' do
      task = create_task(create_space)

      put_json("/tasks/#{task.uuid}", { done: true })

      expect(json['progress']).to include('current' => nil, 'end' => nil, 'ratio' => 1.0)
    end

    it 'overwrites as usual when the same call carries a number' do
      task = create_task(create_space)
      put_json("/tasks/#{task.uuid}", { current: 900, end: 1000, values: { errors: 3 } })

      put_json("/tasks/#{task.uuid}", { current: 1000, done: true })

      expect(json['progress']).to include('current' => 1000, 'end' => nil)
      expect(json['progress']['values']).to eq({})
    end
  end
end
