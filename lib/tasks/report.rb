# frozen_string_literal: true

module Tasks
  module Report
    module_function

    def call(task, current: nil, end_value: nil, values: nil, done: false)
      state = progress(task, current:, end_value:, values:, done:)

      return false if task.finished_at?
      return false unless done || state&.complete?

      finish(task)

      true
    end

    def progress(task, current:, end_value:, values:, done:)
      return nil if done && current.nil? && end_value.nil? && values.nil?

      TaskStates.write(task.uuid, current:, end_value:, values:)
    end

    def finish(task)
      now = Time.current

      task.update!(finished_at: now, duration: (now - task.created_at).round)

      CompletionNotificationJob.perform_later(task.uuid)
    end
  end
end
