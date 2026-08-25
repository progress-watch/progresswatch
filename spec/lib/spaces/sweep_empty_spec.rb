# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spaces::SweepEmpty do
  let(:long_ago) { described_class::EMPTY_FOR.ago - 1.day }

  it 'removes a space that has never held a task' do
    space = create_space
    space.update!(created_at: long_ago)

    expect { described_class.call }.to change(Space, :count).by(-1)
    expect(Space.exists?(space.uuid)).to be(false)
  end

  it 'keeps a space that has a task, however old' do
    space = create_space
    create_task(space, title: 'Reported once')
    space.update!(created_at: long_ago)

    expect { described_class.call }.not_to change(Space, :count)
  end

  it 'keeps a young empty space' do
    create_space

    expect { described_class.call }.not_to change(Space, :count)
  end

  it 'reports how many it took' do
    2.times { create_space.update!(created_at: long_ago) }

    expect(described_class.call).to eq(2)
  end
end
