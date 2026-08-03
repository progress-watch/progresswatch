# frozen_string_literal: true

module PushDelivery
  # Sends to every browser that opted in on this space. Safe to retry, as the seam
  # requires: a resend is at worst a duplicate notification, and the service worker
  # collapses those by task uuid.
  class WebPush
    # 404 and 410 are the push service saying this endpoint is gone for good — the
    # browser was reinstalled, or permission was revoked. Keeping the row would mean
    # failing forever on every completion.
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
        task_uuid: payload[:task_uuid],
        url: "/s/#{payload.fetch(:space_uuid)}"
      }
    end
  end
end
