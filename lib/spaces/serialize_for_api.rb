# frozen_string_literal: true

module Spaces
  module SerializeForApi
    module_function

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
