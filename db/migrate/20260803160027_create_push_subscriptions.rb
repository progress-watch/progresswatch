# frozen_string_literal: true

class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions, id: false do |t|
      t.string :uuid, limit: 36, null: false, primary_key: true
      t.string :space_uuid, limit: 36, null: false
      t.text :endpoint, null: false
      # A unique index over TEXT is not portable across both adapters.
      t.string :endpoint_digest, limit: 64, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.datetime :created_at, null: false
    end

    add_index :push_subscriptions, :space_uuid

    add_index :push_subscriptions, %i[space_uuid endpoint_digest], unique: true

    add_foreign_key :push_subscriptions, :spaces, column: :space_uuid, primary_key: :uuid
  end
end
