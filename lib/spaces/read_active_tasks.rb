# frozen_string_literal: true

module Spaces
  module ReadActiveTasks
    module_function

    def call(space)
      Tasks::PrepareForDashboard.call(ReadTasks.call(space, state: :active))
    end
  end
end
