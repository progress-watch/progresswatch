# frozen_string_literal: true

class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable
  rescue_from TaskStates::InvalidValues, with: :bad_request

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
end
