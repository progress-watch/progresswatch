# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spaces::ReadTasks do
  let(:space) { create_space }

  # The cursor is an instant, so the fixtures need distinct ones. Real rows differ by
  # microseconds, which is why the serializer emits them.
  def seed(count)
    Array.new(count) do |index|
      task = create_task(space, title: "Task #{index}")
      task.update!(created_at: (count - index).hours.ago)
      task
    end.sort_by(&:created_at)
  end

  def titles(...) = described_class.call(space, ...).map { |task| task['title'] }

  it 'returns the whole space in creation order when no window is given' do
    seed(3)

    expect(titles).to eq(['Task 0', 'Task 1', 'Task 2'])
  end

  it 'counts a bare limit back from the newest' do
    seed(5)

    expect(titles(limit: 2)).to eq(['Task 3', 'Task 4'])
  end

  it 'walks backwards from a before cursor, newest first' do
    tasks = seed(5)

    expect(titles(before: tasks[2].created_at.utc.iso8601(6), limit: 2)).to eq(['Task 0', 'Task 1'])
  end

  it 'walks forwards from an after cursor, oldest first' do
    tasks = seed(5)

    expect(titles(after: tasks[2].created_at.utc.iso8601(6), limit: 2)).to eq(['Task 3', 'Task 4'])
  end

  it 'excludes the cursor itself from both directions' do
    tasks = seed(3)
    at = tasks[1].created_at.utc.iso8601(6)

    expect(titles(before: at)).not_to include('Task 1')
    expect(titles(after: at)).not_to include('Task 1')
  end

  it 'filters by state so the dashboard can poll only what still moves' do
    seed(3)
    Tasks::Report.call(space.tasks.order(:created_at).first, done: true)

    expect(titles(state: :finished).size).to eq(1)
    expect(titles(state: :active).size).to eq(2)
  end

  it 'never counts a child against the limit, and never cuts one off' do
    parent = create_task(space, title: 'Deploy')
    2.times { |index| create_task(space, title: "Step #{index}", parent_uuid: parent.uuid) }

    result = described_class.call(space, limit: 1)

    expect(result.pluck('title')).to eq(['Deploy'])
    expect(result.first['children'].pluck('title')).to eq(['Step 0', 'Step 1'])
  end

  describe 'a window it cannot honour' do
    it 'refuses a cursor that is not a timestamp' do
      expect { described_class.call(space, before: 'yesterday') }
        .to raise_error(described_class::InvalidWindow, /ISO 8601/)
    end

    it 'refuses a state that is neither' do
      expect { described_class.call(space, state: 'running') }
        .to raise_error(described_class::InvalidWindow, /active or finished/)
    end

    it 'refuses a limit that is not a whole number' do
      expect { described_class.call(space, limit: '3.5') }
        .to raise_error(described_class::InvalidWindow, /whole number/)
      expect { described_class.call(space, limit: '0') }
        .to raise_error(described_class::InvalidWindow, /at least 1/)
    end
  end
end
