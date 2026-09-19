# frozen_string_literal: true

module PushDelivery
  class Subscribers
    def call(payload)
      PushSubscription.where(space_uuid: payload.fetch(:space_uuid)).find_each do |subscription|
        backend_for(subscription)&.deliver(subscription, payload)
      end
    end

    private

    def backend_for(subscription)
      if subscription.apns?
        return Apns.new if ProgressWatch.apns?

        Relay.new if ProgressWatch.push_relay?
      elsif ProgressWatch.web_push?
        WebPush.new
      end
    end
  end
end
