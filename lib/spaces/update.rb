# frozen_string_literal: true

module Spaces
  # Only the two cosmetic fields. A space's uuid is its identity and its credential,
  # and nothing may move a task between spaces, so there is nothing else to change.
  #
  # An omitted key leaves the field alone; an explicit empty string clears it. That is
  # the opposite of how a task write behaves, and deliberately so — a task reporter
  # always knows its whole state, whereas whoever renames a space rarely means to drop
  # its icon in the same breath.
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
