# frozen_string_literal: true

class Space < ApplicationRecord
  self.primary_key = :uuid

  attribute :uuid, :string, default: -> { SecureRandom.uuid }

  has_many :tasks, foreign_key: :space_uuid, inverse_of: :space, dependent: :destroy
  has_many :push_subscriptions, foreign_key: :space_uuid, inverse_of: :space, dependent: :delete_all

  validates :uuid, presence: true
  validate :icon_is_one_character

  private

  def icon_is_one_character
    return if icon.blank?

    errors.add(:icon, 'must be a single character') unless icon.grapheme_clusters.size == 1
  end
end
