# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Parent aggregation' do
  let(:space) { create_space }
  let(:parent) { create_task(space, title: 'Deploy') }

  def child(title)
    create_task(space, title: title, parent_uuid: parent.uuid)
  end

  def parent_progress
    get "/tasks/#{parent.uuid}"
    json['progress']
  end

  it "averages the children's ratios" do
    a = child('Build')
    b = child('Test')

    put_json "/tasks/#{a.uuid}", { current: 100, end: 100 }
    put_json "/tasks/#{b.uuid}", { current: 20, end: 100 }

    expect(parent_progress).to include('aggregated' => true)
    expect(parent_progress['ratio']).to be_within(0.0001).of(0.6)
  end

  it 'counts finished children as the raw current/end numbers' do
    a = child('Build')
    child('Test')
    child('Ship')

    put_json "/tasks/#{a.uuid}", { current: 10, end: 10 }

    expect(parent_progress).to include('current' => 1, 'end' => 3)
  end

  it "ignores the parent's own current and end once it has children" do
    a = child('Build')
    put_json "/tasks/#{parent.uuid}", { current: 999, end: 1000 }
    put_json "/tasks/#{a.uuid}", { current: 25, end: 100 }

    expect(parent_progress['ratio']).to be_within(0.0001).of(0.25)
    expect(parent_progress['current']).to eq(0)
  end

  it "still carries the parent's own values, so it can report a log line" do
    child('Build')
    put_json "/tasks/#{parent.uuid}", { values: { log: 'waiting on build' } }

    expect(parent_progress['values']).to eq('log' => 'waiting on build')
  end

  it 'uses its own values when it has no children' do
    put_json "/tasks/#{parent.uuid}", { current: 3, end: 4 }

    expect(parent_progress).to include('aggregated' => false, 'current' => 3, 'end' => 4)
    expect(parent_progress['ratio']).to be_within(0.0001).of(0.75)
  end

  describe 'no division by zero' do
    it 'treats an end of zero as an unknown denominator, not an error' do
      a = child('Build')
      put_json "/tasks/#{a.uuid}", { current: 5, end: 0 }

      expect(response).to have_http_status(:ok)
      expect(json['progress']['ratio']).to be_nil
      expect(parent_progress['ratio']).to eq(0.0)
    end

    it 'treats a missing end as an unknown denominator' do
      a = child('Build')
      put_json "/tasks/#{a.uuid}", { current: 5 }

      expect(json['progress']['ratio']).to be_nil
      expect(parent_progress['ratio']).to eq(0.0)
    end

    it 'handles children that have reported nothing at all' do
      child('Build')
      child('Test')

      expect(parent_progress['ratio']).to eq(0.0)
      expect(parent_progress['current']).to eq(0)
      expect(parent_progress['end']).to eq(2)
    end

    it 'clamps a child that overshoots its end' do
      a = child('Build')
      b = child('Test')
      put_json "/tasks/#{a.uuid}", { current: 500, end: 100 }

      expect(json['progress']['ratio']).to eq(1.0)
      put_json "/tasks/#{b.uuid}", { current: 0, end: 100 }
      expect(parent_progress['ratio']).to be_within(0.0001).of(0.5)
    end
  end

  it 'counts a finished child as complete even after Redis forgets it' do
    a = child('Build')
    b = child('Test')
    put_json "/tasks/#{a.uuid}", { current: 10, end: 10 }
    ProgressWatch::PROGRESS_REDIS.with(&:flushdb)
    put_json "/tasks/#{b.uuid}", { current: 0, end: 10 }

    expect(parent_progress['ratio']).to be_within(0.0001).of(0.5)
    expect(parent_progress['current']).to eq(1)
  end

  describe 'finishing a parent' do
    let!(:built) { child('Build') }
    let!(:pushing) { child('Push image') }
    let!(:restart) { child('Restart workers') }

    before do
      put_json "/tasks/#{built.uuid}", { done: true }
      put_json "/tasks/#{pushing.uuid}", { current: 64, end: 100 }
    end

    it 'stops the steps still open, with their numbers as they were, and notifies for the parent alone' do
      expect { put_json "/tasks/#{parent.uuid}", { done: true } }
        .to have_enqueued_job(CompletionNotificationJob).exactly(:once).with(parent.uuid)

      get "/tasks/#{parent.uuid}"
      steps = json['children'].index_by { |step| step['title'] }

      expect(steps.values.pluck('finished_at')).to all(be_present)
      expect(steps.transform_values { |step| step['stopped'] })
        .to eq('Build' => false, 'Push image' => true, 'Restart workers' => true)
      expect(steps['Push image']['progress']).to include('current' => 64, 'end' => 100, 'ratio' => 0.64)
      expect(steps['Restart workers']['progress']).to be_nil
      expect(json['stopped']).to be(false)
      expect(json['progress']).to include('current' => 1, 'end' => 3)
    end

    it 'shows a stopped step as stopped on the page, not as done and not as waiting' do
      put_json "/tasks/#{parent.uuid}", { done: true }

      get "/s/#{space.uuid}/tasks", params: { state: 'finished' }, headers: { 'Turbo-Frame' => 'finished' }
      page = response.parsed_body
      badges = page.css('li li').to_h { |step| [step.at_css('span').text.strip, step.css('.badge').text.strip] }

      expect(badges).to include('Push image' => 'stopped', 'Restart workers' => 'stopped')
      expect(badges['Build']).to start_with('finished')
      expect(response.body).not_to include('Waiting for data')
    end

    it 'leaves the parent open when every step has finished on its own' do
      [pushing, restart].each { |step| put_json "/tasks/#{step.uuid}", { done: true } }

      expect(parent.reload.finished_at).to be_nil
    end

    it 'tells a step that ended by itself from one its job stopped, asked about the step alone' do
      put_json "/tasks/#{parent.uuid}", { done: true }

      get "/tasks/#{pushing.uuid}"
      expect(json).to include('stopped' => true)
      expect(json['progress']['ratio']).to eq(0.64)

      get "/tasks/#{built.uuid}"
      expect(json).to include('stopped' => false)
      expect(json['progress']['ratio']).to eq(1.0)
    end
  end
end
