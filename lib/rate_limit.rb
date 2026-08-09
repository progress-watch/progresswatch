# frozen_string_literal: true

# One number turns this on, and its absence turns it off — which covers a self-hoster who
# wants a limit and one who does not, without either of them pretending to be the hosted
# deployment. docuseal gates the same helper on `multitenant?`; here the flag would have
# been a second thing to reason about for no gain.
#
# It counts creations, not requests. Reporting progress is the one call a legitimate
# client makes every second, and it writes to Redis under a TTL — it is the cheap one, and
# limiting it would break the product to protect nothing.
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

  # A fixed window from the first creation, not a sliding one: NX leaves an existing TTL
  # alone, so a client cannot push the reset further away by continuing to knock. TTL is
  # read inside the same transaction, so it is the window this request belongs to.
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
