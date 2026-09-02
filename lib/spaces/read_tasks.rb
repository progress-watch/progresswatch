# frozen_string_literal: true

module Spaces
  module ReadTasks
    InvalidWindow = Class.new(StandardError)

    STATES = %w[active finished].freeze

    module_function

    def call(space, before: nil, after: nil, limit: nil, state: nil, query: nil)
      tops = matching(space.tasks, query).where(parent_uuid: nil)
      parents = window(tops, before:, after:, limit:, state: state_filter(state))
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

    def matching(tasks, query)
      return tasks if query.blank?

      term = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
      matched = Task.arel_table[:title].lower.matches(term, '\\')
      parents = tasks.where(matched).where.not(parent_uuid: nil).select(:parent_uuid)

      tasks.where(matched).or(tasks.where(uuid: parents))
    end

    def timestamp(value)
      Time.iso8601(value.to_s)
    rescue ArgumentError
      raise InvalidWindow, "#{value.inspect} is not an ISO 8601 timestamp"
    end

    def state_filter(state)
      return nil if state.nil?

      raise InvalidWindow, "state must be active or finished, got #{state.inspect}" unless STATES.include?(state.to_s)

      state.to_sym
    end

    def count(limit)
      return nil if limit.nil?
      raise InvalidWindow, "limit must be a whole number, got #{limit.inspect}" unless /\A\d+\z/.match?(limit.to_s)
      raise InvalidWindow, 'limit must be at least 1' if limit.to_i.zero?

      limit.to_i
    end
  end
end
