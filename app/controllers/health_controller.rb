# frozen_string_literal: true

class HealthController < ApplicationController
  def show
    checks = { database: database_ok?, redis: redis_ok?, worker: worker_ok? }
    ok = checks.values_at(:database, :redis).all?

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

  def worker_ok?
    Sidekiq::ProcessSet.new.any?
  rescue StandardError
    false
  end
end
