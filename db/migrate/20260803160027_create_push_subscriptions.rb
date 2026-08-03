# frozen_string_literal: true

class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions, id: false do |t|
      t.string :uuid, limit: 36, null: false, primary_key: true
      t.string :space_uuid, limit: 36, null: false
      t.text :endpoint, null: false
      # An endpoint is a URL of unbounded length, and a unique index over TEXT is not
      # portable between SQLite and PostgreSQL. The digest is what carries uniqueness.
      t.string :endpoint_digest, limit: 64, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.datetime :created_at, null: false
    end

    add_index :push_subscriptions, :space_uuid

    # A browser re-subscribing to the same space replaces its row rather than adding one,
    # or every completion sends duplicates.
    add_index :push_subscriptions, %i[space_uuid endpoint_digest], unique: true

    add_foreign_key :push_subscriptions, :spaces, column: :space_uuid, primary_key: :uuid
  end
end
