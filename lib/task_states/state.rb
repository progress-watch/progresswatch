# frozen_string_literal: true

module TaskStates
  class State
    attr_reader :current, :end_value, :values, :updated_at

    def initialize(current: nil, end_value: nil, values: nil, updated_at: nil)
      @current = current
      @end_value = end_value
      @values = values || {}
      @updated_at = updated_at
    end

    # An `end` of zero is an unknown denominator, not a finished task: without the
    # positive? guard, a task reporting 0 of 0 would complete itself immediately.
    def complete?
      return false if current.nil? || end_value.nil?
      return false unless end_value.positive?

      current >= end_value
    end

    def ratio
      return nil if current.nil? || end_value.nil? || !end_value.positive?

      (current.to_f / end_value).clamp(0.0, 1.0)
    end

    def as_json(*)
      {
        'current' => current,
        'end' => end_value,
        'ratio' => ratio,
        'values' => values,
        'updated_at' => updated_at,
        'aggregated' => false
      }
    end
  end
end
