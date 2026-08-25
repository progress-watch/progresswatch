# frozen_string_literal: true

class Task < ApplicationRecord
  self.primary_key = :uuid

  attribute :uuid, :string, default: -> { SecureRandom.uuid }

  belongs_to :space, foreign_key: :space_uuid, inverse_of: :tasks
  belongs_to :parent, class_name: 'Task', foreign_key: :parent_uuid, optional: true, inverse_of: :children
  has_many :children, class_name: 'Task', foreign_key: :parent_uuid, inverse_of: :parent, dependent: :destroy

  validates :uuid, presence: true
  validate :parent_is_top_level

  private

  def parent_is_top_level
    return if parent_uuid.blank?

    if parent.nil?
      errors.add(:parent_uuid, 'does not reference a known task')
    elsif parent.parent_uuid.present?
      errors.add(:parent_uuid, 'references a task that is already a child; nesting is one level only')
    elsif parent.space_uuid != space_uuid
      errors.add(:parent_uuid, 'references a task in a different space')
    end
  end
end
