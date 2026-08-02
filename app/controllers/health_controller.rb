# frozen_string_literal: true

# Checks its dependencies rather than just returning 200, so the load balancer pulls
# a container with a dead Redis out of rotation instead of letting it fail every poll.
class HealthController < ApplicationController
  def show
    checks = { database: database_ok?, redis: redis_ok? }
    ok = checks.values.all?

    render json: { status: ok ? 'ok' : 'error', **checks }, status: ok ? :ok : :service_unavailable
  end

  private

  def database_ok?
    ActiveRecord::Base.connection.select_value('SELECT 1') == 1
  rescue StandardError
    false
  end

  def redis_ok?
    ProgressWatch::PROGRESS_REDIS.with(&:ping) == 'PONG'
  rescue StandardError
    false
  end
end
