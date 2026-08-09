# frozen_string_literal: true

class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable
  rescue_from TaskStates::InvalidValues, with: :bad_request
  rescue_from RateLimit::LimitApproached, with: :too_many_requests

  private

  def not_found(error)
    render json: { error: error.message }, status: :not_found
  end

  def unprocessable(error)
    render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
  end

  def bad_request(error)
    render json: { error: error.message }, status: :bad_request
  end

  # No Retry-After. The window is an hour and that is public — it is the variable's name
  # and it is on the docs page — but where an address sits inside its own window is not,
  # and handing that over turns a blind retry into a schedule.
  def too_many_requests
    render json: { error: 'Too many spaces or tasks created from this address. The limit resets within the hour.' },
           status: :too_many_requests
  end
end
