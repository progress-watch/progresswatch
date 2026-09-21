# frozen_string_literal: true

module Limits
  MAX_TASK_TITLE_LENGTH = Integer(ENV.fetch('MAX_TASK_TITLE_LENGTH', '500'))
  MAX_TASK_SOURCE_LENGTH = Integer(ENV.fetch('MAX_TASK_SOURCE_LENGTH', '200'))
  MAX_SPACE_TITLE_LENGTH = Integer(ENV.fetch('MAX_SPACE_TITLE_LENGTH', '200'))
  MAX_VALUES_KEY_COUNT = Integer(ENV.fetch('MAX_VALUES_KEY_COUNT', '50'))
  MAX_VALUES_KEY_LENGTH = Integer(ENV.fetch('MAX_VALUES_KEY_LENGTH', '100'))
  MAX_VALUES_STRING_LENGTH = Integer(ENV.fetch('MAX_VALUES_STRING_LENGTH', '10000'))

  VALUES_DESCRIPTION = "At most #{MAX_VALUES_KEY_COUNT} keys of at most #{MAX_VALUES_KEY_LENGTH} characters, or " \
                       "the request is refused with 400. A string is cut to #{MAX_VALUES_STRING_LENGTH} " \
                       'characters, the last one an ellipsis.'.freeze

  module_function

  def cut(text, length)
    text.truncate(length, omission: '…')
  end

  def describe(length)
    "At most #{length} characters; longer is cut to #{length}, the last one an ellipsis."
  end
end
