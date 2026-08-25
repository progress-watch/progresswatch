# frozen_string_literal: true

module Spaces
  module Update
    module_function

    def call(space, title: :unchanged, icon: :unchanged)
      space.title = title.presence unless title == :unchanged
      space.icon = icon.presence unless icon == :unchanged

      space.save!
      space
    end
  end
end
