# frozen_string_literal: true

module Tasks
  # Full overwrite. An omitted `values` clears the stored one rather than merging.
  module Report
    module_function

    def call(task, current: nil, end_value: nil, values: nil, done: false)
      # Judged on what was stored, not on what arrived: write coerces the numbers,
      # and a string "100" reaching its end must count the same as 100.
      state = TaskStates.write(task.uuid, current:, end_value:, values:)

      return false if task.finished_at?
      return false unless done || state.complete?

      finish(task)

      true
    end

    # One UPDATE for the whole life of the task, guarded by the finished_at check
    # above, so the notification fires once.
    def finish(task)
      now = Time.current

      task.update!(finished_at: now, duration: (now - task.created_at).round)

      CompletionNotificationJob.perform_later(task.uuid)
    end
  end
end
