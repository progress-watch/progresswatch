# frozen_string_literal: true

module Api
  class RelayController < ApplicationController
    rescue_from PushDelivery::Apns::InvalidDevice, ActionController::ParameterMissing, with: :bad_request

    rescue_from PushDelivery::Apns::Error do
      head :bad_gateway
    end

    def create
      return head :not_found unless ProgressWatch.apns?

      RateLimit.call("relay:#{request.remote_ip}")

      endpoint = PushDelivery::Apns.endpoint(token: params.require(:token), environment: params.require(:environment))

      head PushDelivery::Apns.new.push(endpoint, notification) == :gone ? :gone : :no_content
    end

    private

    def notification
      PushDelivery::Apns.notification(
        title: params[:title].to_s,
        body: params.require(:body),
        tag: params[:tag].to_s.first(64).presence,
        subscription: params.require(:subscription).to_s.first(36),
        sound: params[:sound] != false
      )
    end

    def too_many_requests
      render json: { error: 'Too many notifications relayed from this address. The limit resets within the hour.' },
             status: :too_many_requests
    end
  end
end
