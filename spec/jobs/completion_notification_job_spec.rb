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
