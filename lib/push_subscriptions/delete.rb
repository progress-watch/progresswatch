# frozen_string_literal: true

module PushSubscriptions
  module Delete
    module_function

    # By endpoint rather than by uuid: the browser knows its own endpoint and nothing
    # else, and handing it a row id would be a second identifier to keep in sync.
    def call(space:, endpoint:)
      space.push_subscriptions.where(endpoint_digest: PushSubscription.digest(endpoint)).delete_all
    end
  end
end
