# frozen_string_literal: true

class PushSubscription < ApplicationRecord
  self.primary_key = :uuid

  attribute :uuid, :string, default: -> { SecureRandom.uuid }

  belongs_to :space, foreign_key: :space_uuid, inverse_of: :push_subscriptions

  validates :endpoint, :endpoint_digest, presence: true
  validates :p256dh, :auth, presence: true, unless: -> { apns? || fcm? }

  def self.digest(endpoint)
    Digest::SHA256.hexdigest(endpoint.to_s)
  end

  def apns?
    PushDelivery::Apns.endpoint?(endpoint)
  end

  def fcm?
    PushDelivery::Fcm.endpoint?(endpoint)
  end
end
