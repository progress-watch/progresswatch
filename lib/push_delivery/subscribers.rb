# frozen_string_literal: true

module PushDelivery
  class Subscribers
    def call(payload)
      subscriptions = PushSubscription.where(space_uuid: payload.fetch(:space_uuid)).to_a
      relayed, direct = subscriptions.partition { |subscription| relayed?(subscription) }

      direct.each { |subscription| backend_for(subscription)&.deliver(subscription, payload) }

      Relay.new.deliver(relayed, payload) if relayed.any?
    end

    private

    def relayed?(subscription)
      (subscription.apns? || subscription.fcm?) && ProgressWatch.push_relay?
    end

    def backend_for(subscription)
      if subscription.apns?
        Apns.new if ProgressWatch.apns?
      elsif !subscription.fcm? && ProgressWatch.web_push?
        WebPush.new
      end
    end
  end
end
