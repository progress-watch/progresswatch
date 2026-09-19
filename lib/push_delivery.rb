# frozen_string_literal: true

module PushDelivery
  CONTENT_MODE = ENV.fetch('PUSH_CONTENT', 'full')

  class Log
    def call(payload)
      Rails.logger.info({ event: 'push.deliver', **payload }.to_json)
    end
  end

  mattr_accessor :backend, default: Log.new

  module_function

  def forget(subscription, payload, code:)
    Rails.logger.warn({ event: 'push.gone', code:, space_uuid: payload.fetch(:space_uuid),
                        endpoint_digest: subscription.endpoint_digest }.to_json)
    subscription.destroy
  end

  def deliver(space_uuid:, task_uuid:, root_uuid:, title:, duration:)
    minimal = CONTENT_MODE == 'minimal'

    backend.call(
      space_uuid:,
      task_uuid:,
      tag: root_uuid,
      renotify: task_uuid == root_uuid,
      duration:,
      title: minimal ? nil : title,
      body: minimal ? 'Task completed' : "#{title.presence || 'Task'} completed"
    )
  end
end
