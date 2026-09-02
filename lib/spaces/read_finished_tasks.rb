# frozen_string_literal: true

module Spaces
  module ReadFinishedTasks
    PAGE = 25

    module_function

    def call(space, before: nil, query: nil)
      tasks = ReadTasks.call(space, state: :finished, limit: PAGE, before:, query:)

      {
        'sections' => Tasks::PrepareForDashboard.sections(tasks),
        'older_than' => (tasks.first['created_at'] if tasks.size == PAGE)
      }
    end
  end
end
