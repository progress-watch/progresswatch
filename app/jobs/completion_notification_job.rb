# frozen_string_literal: true

class CompletionNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(task_uuid)
    task = Task.find_by(uuid: task_uuid)

    return if task.nil?

    PushDelivery.deliver(
      space_uuid: task.space_uuid,
      task_uuid: task.uuid,
      title: task.title,
      duration: task.duration
    )
  end
end
