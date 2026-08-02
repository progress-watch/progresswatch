# frozen_string_literal: true

module Tasks
  module Create
    module_function

    def call(space:, title: nil, source: nil, parent_uuid: nil)
      Task.create!(space:, title:, source:, parent_uuid:)
    end
  end
end
