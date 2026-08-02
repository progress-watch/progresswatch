# frozen_string_literal: true

class Space < ApplicationRecord
  self.primary_key = :uuid

  # In Ruby, never gen_random_uuid(): the same code has to produce the same rows on
  # SQLite and Postgres.
  attribute :uuid, :string, default: -> { SecureRandom.uuid }

  has_many :tasks, foreign_key: :space_uuid, inverse_of: :space, dependent: :destroy

  validates :uuid, presence: true
  validate :icon_is_one_character

  private

  # Grapheme clusters, not characters: 👍 is one codepoint but 👍🏽 is two and a family
  # emoji is five, and all three are one thing on screen. `limit: 16` on the column is
  # the backstop for how many codepoints that can take.
  def icon_is_one_character
    return if icon.blank?

    errors.add(:icon, 'must be a single character') unless icon.grapheme_clusters.size == 1
  end
end
