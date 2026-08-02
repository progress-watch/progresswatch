# frozen_string_literal: true

module Spaces
  # Empty, not idle: this takes a space that has never held a single task, which is
  # what a crawler leaves behind when it loads the landing page and the page mints one.
  # A space with tasks is kept however long nobody looks at it.
  #
  # EMPTY_FOR is a floor, not a schedule. Nothing runs this on a timer — an operator may
  # run it daily or once a year — so what a user can be told is that past 30 days an
  # empty space may go, never that it survives to any particular date.
  #
  # A month, not a week: deleting a real space is unrecoverable — the uuid is the only
  # way back to it — while keeping a bot's costs a few hundred bytes. Someone can put a
  # uuid in a CI secret and not report into it until the next release.
  module SweepEmpty
    EMPTY_FOR = 30.days

    module_function

    def call(now: Time.current)
      Space.where.missing(:tasks).where(created_at: ..(now - EMPTY_FOR)).destroy_all.size
    end
  end
end
