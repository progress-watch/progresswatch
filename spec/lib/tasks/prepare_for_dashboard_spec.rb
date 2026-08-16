# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tasks::PrepareForDashboard do
  def task(title, finished: false, children: [])
    {
      'title' => title,
      'created_at' => Time.current.iso8601,
      'finished_at' => (finished ? '2026-08-02T00:00:00Z' : nil),
      'children' => children
    }
  end

  it 'puts active first and newest first within each group, at both levels' do
    tasks = [task('old running'), task('old done', finished: true),
             task('new running', children: [task('child done', finished: true), task('child running')]),
             task('new done', finished: true)]

    sorted = described_class.call(tasks)

    expect(sorted.pluck('title')).to eq(['new running', 'old running', 'new done', 'old done'])
    expect(sorted.first['children'].pluck('title')).to eq(['child running', 'child done'])
  end

  # sort_by is not stable in Ruby, so equal keys could come back in any order and the
  # polled frame would reshuffle every 2.5 seconds.
  it 'keeps the order it was given within a group, however many share a status' do
    tasks = Array.new(20) { |i| task("t#{i}") }

    expect(described_class.call(tasks).pluck('title')).to eq(19.downto(0).map { |i| "t#{i}" })
  end

  it 'copes with a task that has no children key' do
    expect do
      described_class.call([{ 'title' => 'x', 'created_at' => Time.current.iso8601, 'finished_at' => nil }])
    end.not_to raise_error
  end

  describe 'the labels a template would otherwise compute' do
    def prepared(attrs)
      base = { 'created_at' => Time.current.iso8601, 'finished_at' => nil, 'children' => [] }
      described_class.call([base.merge(attrs)]).first
    end

    def reported(ago)
      { 'progress' => { 'updated_at' => ago.ago.iso8601 } }
    end

    # iso8601 drops the fraction, so an unfrozen clock turns 20 seconds into 21.
    around { |example| freeze_time { example.run } }

    # How long it took and when it happened are different questions. The badge answers the
    # first; without this a board with a week of history never answers the second.
    it 'says when a task finished, coarsely, and spells it out in the tooltip' do
      expect(prepared('finished_at' => 20.seconds.ago.iso8601)['finished_ago']).to eq('just now')
      expect(prepared('finished_at' => 40.minutes.ago.iso8601)['finished_ago']).to eq('40m ago')
      expect(prepared('finished_at' => 5.hours.ago.iso8601)['finished_ago']).to eq('5h ago')
      expect(prepared('finished_at' => 3.days.ago.iso8601)['finished_ago']).to eq('3d ago')

      expect(prepared('finished_at' => '2026-08-02T14:32:00Z')['finished_on']).to eq('2 Aug 2026, 14:32 UTC')
    end

    it 'says neither about a task that is still running' do
      expect(prepared('title' => 'x')).to include('finished_ago' => nil, 'finished_on' => nil)
    end

    it 'reads a duration in the largest unit that fits, dropping a zero tail' do
      expect(prepared('finished_at' => 1.minute.ago.iso8601,
                      'duration' => 45)['finished_label']).to eq('finished in 45s')
      expect(prepared('finished_at' => 1.minute.ago.iso8601,
                      'duration' => 391)['finished_label']).to eq('finished in 6m 31s')
      expect(prepared('finished_at' => 1.minute.ago.iso8601,
                      'duration' => 7_530)['finished_label']).to eq('finished in 2h 5m')
      expect(prepared('finished_at' => 1.minute.ago.iso8601,
                      'duration' => 120)['finished_label']).to eq('finished in 2m')
      expect(prepared('finished_at' => 1.minute.ago.iso8601,
                      'duration' => 7_200)['finished_label']).to eq('finished in 2h')
    end

    it 'says finished with no duration, and nothing at all while running' do
      expect(prepared('finished_at' => 1.minute.ago.iso8601)['finished_label']).to eq('finished')
      expect(prepared({})['finished_label']).to be_nil
    end

    # A parent counts finished children, a leaf counts its own work, and an unknown
    # denominator shows the numerator alone rather than inventing a total.
    it 'labels counts by what the progress actually is' do
      expect(prepared('progress' => { 'current' => 2, 'end' => 5, 'aggregated' => true })['counts_label'])
        .to eq('2/5 done')
      expect(prepared('progress' => { 'current' => 1200, 'end' => 50_000 })['counts_label']).to eq('1200/50000')
      expect(prepared('progress' => { 'current' => 42, 'end' => nil })['counts_label']).to eq('42')
      expect(prepared('progress' => nil)['counts_label']).to be_nil
    end

    it 'says how long a task has waited, however briefly' do
      expect(prepared('created_at' => 20.seconds.ago.iso8601)['idle_label']).to eq('waiting 20s')
      expect(prepared('created_at' => 3.hours.ago.iso8601)['idle_label']).to eq('waiting 3h')
    end

    it 'calls a task idle only once it has been quiet long enough' do
      expect(prepared(reported(9.minutes))['idle_label']).to be_nil
      expect(prepared(reported(2.hours))['idle_label']).to eq('idle 2h')
    end

    it 'says nothing about a task that has finished, however long ago it reported' do
      expect(prepared(reported(2.hours).merge('finished_at' => 1.minute.ago.iso8601))['idle_label']).to be_nil
    end

    it 'falls back to creation for an aggregate that has heard nothing' do
      expect(prepared('progress' => { 'updated_at' => nil, 'aggregated' => true },
                      'created_at' => 40.minutes.ago.iso8601)['idle_label']).to eq('waiting 40m')
    end
  end

  describe '.sections' do
    def finished(title, at)
      { 'title' => title, 'created_at' => at.utc.iso8601(6), 'finished_at' => at.utc.iso8601(6),
        'duration' => 1, 'children' => [] }
    end

    it 'buckets by month, newest month first, newest task first inside one' do
      sections = described_class.sections([
                                            finished('March one', Time.utc(2026, 3, 1)),
                                            finished('March two', Time.utc(2026, 3, 20)),
                                            finished('April', Time.utc(2026, 4, 2))
                                          ])

      expect(sections.pluck('heading')).to eq(['April 2026', 'March 2026'])
      expect(sections.last['tasks'].pluck('title')).to eq(['March two', 'March one'])
    end

    # created_at, not finished_at: the list is already sorted by creation, and grouping on
    # another key lets a bucket appear twice.
    it 'buckets on when a task was created, not when it ended' do
      sections = described_class.sections([finished('Started in March', Time.utc(2026, 3, 31))
                                             .merge('finished_at' => Time.utc(2026, 4, 1).utc.iso8601(6))])

      expect(sections.pluck('heading')).to eq(['March 2026'])
    end
  end
end
