# frozen_string_literal: true

module PushSubscriptions
  module Create
    module_function

    # Upsert, not create: a browser re-subscribing — after a permission reset, a key
    # rotation, or simply a second visit — must replace its row, or one completion sends
    # the same notification several times.
    def call(space:, endpoint:, p256dh:, auth:)
      digest = PushSubscription.digest(endpoint)

      subscription = space.push_subscriptions.find_or_initialize_by(endpoint_digest: digest)
      subscription.update!(endpoint:, p256dh:, auth:)
      subscription
    end
  end
end
