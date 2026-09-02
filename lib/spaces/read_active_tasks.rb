# frozen_string_literal: true

module Spaces
  module ReadActiveTasks
    module_function

    def call(space, query: nil)
      Tasks::PrepareForDashboard.call(ReadTasks.call(space, state: :active, query:))
    end
  end
end
