# frozen_string_literal: true

module Spaces
  module ReadActiveTasks
    module_function

    # Unbounded: this is bounded by how much is running, and history is what grows.
    def call(space)
      Tasks::PrepareForDashboard.call(ReadTasks.call(space, state: :active))
    end
  end
end
