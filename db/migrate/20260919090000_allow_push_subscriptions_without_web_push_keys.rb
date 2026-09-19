# frozen_string_literal: true

class AllowPushSubscriptionsWithoutWebPushKeys < ActiveRecord::Migration[8.1]
  def change
    change_column_null :push_subscriptions, :p256dh, true
    change_column_null :push_subscriptions, :auth, true
  end
end
