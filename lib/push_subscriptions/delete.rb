# frozen_string_literal: true

module PushSubscriptions
  module Delete
    module_function

    def call(space:, endpoint:)
      space.push_subscriptions.where(endpoint_digest: PushSubscription.digest(endpoint)).delete_all
    end
  end
end
