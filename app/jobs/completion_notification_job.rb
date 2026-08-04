# frozen_string_literal: true

class CompletionNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(task_uuid)
    task = Task.find_by(uuid: task_uuid)

    return if task.nil?

    PushDelivery.deliver(
      space_uuid: task.space_uuid,
      task_uuid: task.uuid,
      root_uuid: task.parent_uuid || task.uuid,
      title: display_title(task),
      duration: task.duration
    )
  end

  private

  # A step reads as "Deploy — Build", so a collapsed notification still says which job
  # moved and how far.
  def display_title(task)
    return task.title if task.parent_uuid.blank?

    [Task.find_by(uuid: task.parent_uuid)&.title, task.title].compact_blank.join(' — ').presence
  end
end
