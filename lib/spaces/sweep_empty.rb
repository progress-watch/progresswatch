# frozen_string_literal: true

module Spaces
  module SweepEmpty
    EMPTY_FOR = 30.days

    module_function

    def call(now: Time.current)
      Space.where.missing(:tasks).where(created_at: ..(now - EMPTY_FOR)).destroy_all.size
    end
  end
end
