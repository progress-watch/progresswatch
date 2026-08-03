# frozen_string_literal: true

module PushSubscriptions
  module Create
    module_function

    # Upsert, not create: two rows for one browser means one completion notifies twice.
    def call(space:, endpoint:, p256dh:, auth:)
      digest = PushSubscription.digest(endpoint)

      subscription = space.push_subscriptions.find_or_initialize_by(endpoint_digest: digest)
      subscription.update!(endpoint:, p256dh:, auth:)
      subscription
    end
  end
end
