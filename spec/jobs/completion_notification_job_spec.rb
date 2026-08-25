# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CompletionNotificationJob do
  let(:deliveries) { [] }

  before do
    PushDelivery.backend = ->(payload) { deliveries << payload }
  end

  it 'hands the completed task to the push backend' do
    task = create_task(create_space, title: 'Nightly backup')
    Tasks::Report.call(task, current: 10, end_value: 10)

    described_class.perform_now(task.uuid)

    expect(deliveries.first).to include(task_uuid: task.uuid, title: 'Nightly backup')
  end

  it 'tags a step with its parent, and names both' do
    space = create_space
    parent = create_task(space, title: 'Deploy')
    step = create_task(space, title: 'Build', parent_uuid: parent.uuid)

    described_class.perform_now(step.uuid)
    described_class.perform_now(parent.uuid)

    expect(deliveries.first).to include(tag: parent.uuid, renotify: false, title: 'Deploy — Build')
    expect(deliveries.last).to include(tag: parent.uuid, renotify: true, title: 'Deploy')
  end

  it 'tags a task with no parent as itself' do
    task = create_task(create_space, title: 'Standalone')

    described_class.perform_now(task.uuid)

    expect(deliveries.first).to include(tag: task.uuid, renotify: true)
  end

  it 'does nothing for a task that has since been deleted' do
    expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
    expect(deliveries).to be_empty
  end

  it 'omits the title when the operator has asked for minimal relay content' do
    task = create_task(create_space, title: 'Secret project')
    stub_const('PushDelivery::CONTENT_MODE', 'minimal')

    described_class.perform_now(task.uuid)

    expect(deliveries.first[:title]).to be_nil
    expect(deliveries.first[:body]).to eq('Task completed')
  end
end
