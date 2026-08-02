# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tasks::PrepareForDashboard do
  def task(title, finished: false, children: [])
    { 'title' => title, 'finished_at' => (finished ? '2026-08-02T00:00:00Z' : nil), 'children' => children }
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
    expect { described_class.call([{ 'title' => 'x', 'finished_at' => nil }]) }.not_to raise_error
  end

  describe 'the labels a template would otherwise compute' do
    def prepared(attrs)
      described_class.call([{ 'finished_at' => nil, 'children' => [] }.merge(attrs)]).first
    end

    it 'reads a duration in the largest unit that fits' do
      expect(prepared('finished_at' => 'x', 'duration' => 45)['finished_label']).to eq('finished in 45s')
      expect(prepared('finished_at' => 'x', 'duration' => 391)['finished_label']).to eq('finished in 6m 31s')
      expect(prepared('finished_at' => 'x', 'duration' => 7_530)['finished_label']).to eq('finished in 2h 5m')
    end

    it 'says finished with no duration, and nothing at all while running' do
      expect(prepared('finished_at' => 'x')['finished_label']).to eq('finished')
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
  end
end
