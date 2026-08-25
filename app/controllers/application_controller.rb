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

  def too_many_requests
    render json: { error: 'Too many spaces or tasks created from this address. The limit resets within the hour.' },
           status: :too_many_requests
  end
end
