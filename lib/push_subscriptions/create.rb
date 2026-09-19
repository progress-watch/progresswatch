# frozen_string_literal: true

module PushSubscriptions
  module Create
    module_function

    def call(space:, endpoint:, p256dh: nil, auth: nil)
      digest = PushSubscription.digest(endpoint)

      subscription = space.push_subscriptions.find_or_initialize_by(endpoint_digest: digest)
      subscription.update!(endpoint:, p256dh:, auth:)
      subscription
    end
  end
end
