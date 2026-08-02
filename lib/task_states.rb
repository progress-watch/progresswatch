# frozen_string_literal: true

# Nothing outside this module may touch ProgressWatch::PROGRESS_REDIS.
# Reads return nil for a missing key, which is a normal state.
module TaskStates
  InvalidValues = Class.new(StandardError)

  VALUE_TYPES = [String, Numeric, TrueClass, FalseClass, NilClass].freeze

  module_function

  def key(task_uuid)
    "#{ProgressWatch::PROGRESS_KEY_PREFIX}:#{task_uuid}"
  end

  def read(task_uuid)
    parse(ProgressWatch::PROGRESS_REDIS.with { |r| r.get(key(task_uuid)) })
  end

  def read_many(task_uuids)
    return {} if task_uuids.empty?

    raws = ProgressWatch::PROGRESS_REDIS.with { |r| r.mget(*task_uuids.map { |uuid| key(uuid) }) }

    task_uuids.zip(raws).to_h { |uuid, raw| [uuid, parse(raw)] }
  end

  def write(task_uuid, current: nil, end_value: nil, values: nil)
    payload = {
      'current' => numeric(current, :current),
      'end' => numeric(end_value, :end),
      'values' => normalize_values(values),
      'updated_at' => Time.current.utc.iso8601
    }

    ProgressWatch::PROGRESS_REDIS.with do |redis|
      redis.set(key(task_uuid), JSON.generate(payload), ex: ProgressWatch::PROGRESS_TTL_SECONDS)
    end

    State.new(current: payload['current'], end_value: payload['end'],
              values: payload['values'], updated_at: payload['updated_at'])
  end

  def parse(raw)
    return nil if raw.nil?

    data = JSON.parse(raw)

    State.new(current: data['current'], end_value: data['end'],
              values: data['values'] || {}, updated_at: data['updated_at'])
  rescue JSON::ParserError
    nil
  end

  # Numeric strings are accepted on purpose: shell scripts interpolating into curl
  # produce them constantly.
  def numeric(value, field)
    return nil if value.nil?
    return value if value.is_a?(Numeric)

    parsed = Float(value)

    (parsed % 1).zero? ? parsed.to_i : parsed
  rescue ArgumentError, TypeError
    raise InvalidValues, "#{field} must be a number"
  end

  # Nesting is rejected rather than stored, so no client starts depending on a shape
  # the app has no way to render.
  def normalize_values(values)
    return {} if values.nil?
    raise InvalidValues, 'values must be an object' unless values.is_a?(Hash)

    values.to_h do |key, value|
      raise InvalidValues, "values.#{key} must be a string, number, boolean or null" unless
        VALUE_TYPES.any? { |type| value.is_a?(type) }

      [key.to_s, value]
    end
  end
end
