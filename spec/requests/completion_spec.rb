# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Completion' do
  let(:space) { create_space }
  let(:task) { create_task(space, title: 'Crawl') }

  it 'completes when current reaches end' do
    expect do
      put_json "/tasks/#{task.uuid}", { current: 100, end: 100 }
    end.to have_enqueued_job(CompletionNotificationJob).with(task.uuid)

    expect(json['finished_at']).to be_present
    expect(json['duration']).to be >= 0
    expect(task.reload.finished_at).to be_present
  end

  it 'completes on an explicit done, whatever the numbers say' do
    expect do
      put_json "/tasks/#{task.uuid}", { current: 3, end: 100, done: true }
    end.to have_enqueued_job(CompletionNotificationJob)

    expect(task.reload.finished_at).to be_present
  end

  it 'completes on done with no numbers at all' do
    put_json "/tasks/#{task.uuid}", { done: true }

    expect(task.reload.finished_at).to be_present
  end

  it 'does not complete while current is short of end' do
    expect do
      put_json "/tasks/#{task.uuid}", { current: 99, end: 100 }
    end.not_to have_enqueued_job(CompletionNotificationJob)

    expect(task.reload.finished_at).to be_nil
  end

  it 'does not complete on a zero end, where the denominator is unknown' do
    expect do
      put_json "/tasks/#{task.uuid}", { current: 0, end: 0 }
    end.not_to have_enqueued_job(CompletionNotificationJob)

    expect(task.reload.finished_at).to be_nil
  end

  it 'writes finished_at once and notifies once, however many times it is told' do
    put_json "/tasks/#{task.uuid}", { current: 100, end: 100 }
    finished_at = task.reload.finished_at

    expect do
      put_json "/tasks/#{task.uuid}", { current: 100, end: 100 }
      put_json "/tasks/#{task.uuid}", { done: true }
    end.not_to have_enqueued_job(CompletionNotificationJob)

    expect(task.reload.finished_at).to eq(finished_at)
  end

  it 'keeps accepting progress writes after finishing' do
    put_json "/tasks/#{task.uuid}", { current: 100, end: 100 }
    put_json "/tasks/#{task.uuid}", { current: 100, end: 100, values: { log: 'cleaning up' } }

    expect(response).to have_http_status(:ok)
    expect(json['progress']['values']).to eq('log' => 'cleaning up')
  end
end
