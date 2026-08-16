# frozen_string_literal: true

module Tasks
  # Full overwrite. An omitted `values` clears the stored one rather than merging.
  module Report
    module_function

    def call(task, current: nil, end_value: nil, values: nil, done: false)
      # Judged on what was stored, not on what arrived: write coerces the numbers,
      # and a string "100" reaching its end must count the same as 100.
      state = progress(task, current:, end_value:, values:, done:)

      return false if task.finished_at?
      return false unless done || state&.complete?

      finish(task)

      true
    end

    # Completion is a disk fact and progress is a Redis fact, so a call that carries only
    # `done` sets the one and leaves the other alone. Overwriting anyway wiped the counts
    # a watcher was reading the moment their task finished — reported from outside on
    # 2026-08-16, and our own `progresswatch done` did it to every task it closed.
    #
    # Not a merge, and the overwrite rule is untouched: any call that names a progress
    # field still replaces all of them.
    def progress(task, current:, end_value:, values:, done:)
      return nil if done && current.nil? && end_value.nil? && values.nil?

      TaskStates.write(task.uuid, current:, end_value:, values:)
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
