# frozen_string_literal: true

class Space < ApplicationRecord
  self.primary_key = :uuid

  # In Ruby, never gen_random_uuid(): the same code has to produce the same rows on
  # SQLite and Postgres.
  attribute :uuid, :string, default: -> { SecureRandom.uuid }

  has_many :tasks, foreign_key: :space_uuid, inverse_of: :space, dependent: :destroy

  validates :uuid, presence: true
end
