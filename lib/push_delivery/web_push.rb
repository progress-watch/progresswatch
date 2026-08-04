# frozen_string_literal: true

module PushDelivery
  class WebPush
    # The push service saying this endpoint is gone for good. Keeping the row would mean
    # failing on every completion from now on.
    GONE = [404, 410].freeze

    def call(payload)
      subscriptions(payload).find_each do |subscription|
        deliver(subscription, payload)
      end
    end

    private

    def subscriptions(payload)
      PushSubscription.where(space_uuid: payload.fetch(:space_uuid))
    end

    def deliver(subscription, payload)
      ::WebPush.payload_send(
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
        message: message(payload).to_json,
        vapid: {
          subject: ProgressWatch::VAPID_SUBJECT,
          public_key: ProgressWatch::VAPID_PUBLIC_KEY,
          private_key: ProgressWatch::VAPID_PRIVATE_KEY
        }
      )
    rescue ::WebPush::ResponseError => e
      raise unless GONE.include?(e.response.code.to_i)

      subscription.destroy
    end

    def message(payload)
      {
        title: payload[:title].presence || 'Progress Watch',
        body: payload.fetch(:body),
        tag: payload[:tag],
        renotify: payload[:renotify],
        url: "/s/#{payload.fetch(:space_uuid)}"
      }
    end
  end
end
