# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /tasks/:uuid/report' do
  let(:task) { create_task(create_space) }

  it 'writes the same state a PUT would' do
    get "/tasks/#{task.uuid}/report", params: { current: 1200, end: 50_000 }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['progress']).to include('current' => 1200, 'end' => 50_000, 'ratio' => 0.024)
  end

  it 'takes the numbers as the text a query string can carry' do
    get "/tasks/#{task.uuid}/report", params: { current: '3', end: '4', 'values' => { 'errors' => '2' } }

    expect(response.parsed_body['progress']).to include('current' => 3.0, 'end' => 4.0)
    expect(response.parsed_body['progress']['values']).to eq('errors' => '2')
  end

  it 'finishes the task, both ways' do
    get "/tasks/#{task.uuid}/report", params: { done: 'true' }
    expect(response.parsed_body['finished_at']).to be_present

    other = create_task(create_space)
    get "/tasks/#{other.uuid}/report", params: { current: 10, end: 10 }
    expect(response.parsed_body['finished_at']).to be_present
  end

  it 'leaves reading a task a read' do
    get "/tasks/#{task.uuid}", params: { current: 99, end: 100 }

    expect(response.parsed_body['progress']).to be_nil
  end

  it 'is 404 for a task that does not exist' do
    get "/tasks/#{SecureRandom.uuid}/report", params: { current: 1 }

    expect(response).to have_http_status(:not_found)
  end
end
