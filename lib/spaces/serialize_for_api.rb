# frozen_string_literal: true

module Spaces
  module SerializeForApi
    module_function

    # One MGET whatever the task count: this is polled every 2-3 seconds. The window is
    # unset by default, so the plain read still returns the whole space.
    def call(space, before: nil, after: nil, limit: nil)
      {
        'uuid' => space.uuid,
        'title' => space.title,
        'icon' => space.icon,
        'tasks' => ReadTasks.call(space, before:, after:, limit:)
      }
    end
  end
end
