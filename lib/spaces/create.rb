# frozen_string_literal: true

module Spaces
  module Create
    module_function

    def call(title: nil, icon: nil)
      Space.create!(title:, icon: icon.presence)
    end
  end
end
