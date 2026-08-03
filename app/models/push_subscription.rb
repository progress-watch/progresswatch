# frozen_string_literal: true

class PushSubscription < ApplicationRecord
  self.primary_key = :uuid

  attribute :uuid, :string, default: -> { SecureRandom.uuid }

  belongs_to :space, foreign_key: :space_uuid, inverse_of: :push_subscriptions

  validates :endpoint, :endpoint_digest, :p256dh, :auth, presence: true

  # A pure reader over the record's own column, so it stays on the model: the digest is
  # what the unique index is built from, and both writes and lookups need the same one.
  def self.digest(endpoint)
    Digest::SHA256.hexdigest(endpoint.to_s)
  end
end
