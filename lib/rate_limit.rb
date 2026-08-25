# frozen_string_literal: true

module RateLimit
  LimitApproached = Class.new(StandardError)

  PER_HOUR = ENV['RATE_LIMIT_PER_HOUR'].presence&.to_i
  WINDOW = 1.hour
  KEY_PREFIX = 'pw:rate'

  module_function

  def call(address)
    return true if PER_HOUR.blank?

    count, ttl = count_and_ttl("#{KEY_PREFIX}:#{address}")

    raise LimitApproached, ttl if count > PER_HOUR

    true
  end

  # NX, or a client pushes its own reset further away by continuing to knock.
  def count_and_ttl(key)
    ProgressWatch::PROGRESS_REDIS.with do |redis|
      redis.multi do |transaction|
        transaction.incr(key)
        transaction.expire(key, WINDOW.to_i, nx: true)
        transaction.ttl(key)
      end.values_at(0, 2)
    end
  end
end
