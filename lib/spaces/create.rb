# frozen_string_literal: true

module Spaces
  module Create
    module_function

    def call(title: nil)
      Space.create!(title:)
    end
  end
end
