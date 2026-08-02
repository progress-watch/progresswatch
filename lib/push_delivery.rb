# frozen_string_literal: true

# The seam where FCM/APNs will plug in. A backend is anything responding to
# #call(payload), and it must be safe to retry — Sidekiq will.
module PushDelivery
  CONTENT_MODE = ENV.fetch('PUSH_CONTENT', 'full')

  class Log
    def call(payload)
      Rails.logger.info({ event: 'push.deliver', **payload }.to_json)
    end
  end

  mattr_accessor :backend, default: Log.new

  module_function

  def deliver(space_uuid:, task_uuid:, title:, duration:)
    minimal = CONTENT_MODE == 'minimal'

    backend.call(
      space_uuid:,
      task_uuid:,
      duration:,
      title: minimal ? nil : title,
      body: minimal ? 'Task completed' : "#{title.presence || 'Task'} completed"
    )
  end
end
