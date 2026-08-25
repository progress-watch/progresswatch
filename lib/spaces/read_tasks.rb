# frozen_string_literal: true

module Spaces
  module ReadTasks
    InvalidWindow = Class.new(StandardError)

    module_function

    def call(space, before: nil, after: nil, limit: nil, state: nil)
      parents = window(space.tasks.where(parent_uuid: nil), before:, after:, limit:, state:)
      children = space.tasks.where(parent_uuid: parents.map(&:uuid)).order(:created_at).to_a
      states = TaskStates.read_many((parents + children).map(&:uuid))
      by_parent = children.group_by(&:parent_uuid)

      parents.map { |task| Tasks::SerializeForApi.render(task, by_parent[task.uuid] || [], states) }
    end

    def window(scope, before:, after:, limit:, state:)
      scope = scope.where(finished_at: nil) if state == :active
      scope = scope.where.not(finished_at: nil) if state == :finished
      scope = scope.where(created_at: ...timestamp(before)) if before
      # No exclusive-begin range literal, hence the negation.
      scope = scope.where.not(created_at: ..timestamp(after)) if after
      return scope.order(:created_at).limit(count(limit)).to_a if after || limit.nil?

      scope.order(created_at: :desc).limit(count(limit)).to_a.reverse
    end

    def timestamp(value)
      Time.iso8601(value.to_s)
    rescue ArgumentError
      raise InvalidWindow, "#{value.inspect} is not an ISO 8601 timestamp"
    end

    def count(limit)
      return nil if limit.nil?
      raise InvalidWindow, "limit must be a whole number, got #{limit.inspect}" unless /\A\d+\z/.match?(limit.to_s)
      raise InvalidWindow, 'limit must be at least 1' if limit.to_i.zero?

      limit.to_i
    end
  end
end
