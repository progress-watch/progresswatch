# frozen_string_literal: true

module Api
  class RelayController < ApplicationController
    rescue_from PushDelivery::Apns::InvalidDevice, ActionController::ParameterMissing, with: :bad_request

    rescue_from PushDelivery::Apns::Error do
      head :bad_gateway
    end

    def create
      return head :not_found unless ProgressWatch.apns?
      return head :bad_request if devices.size > PushDelivery::Relay::BATCH

      RateLimit.call("relay:#{request.remote_ip}")

      served, unavailable = devices.partition { |device| device[:service] == 'apns' }
      messages = served.map { |device| [device[:subscription], endpoint(device), notification(device)] }
      gone = messages.select { |_, endpoint, message| apns.push(endpoint, message) == :gone }.map(&:first)

      render json: { gone:, unavailable: unavailable.pluck(:subscription) }
    end

    private

    def devices
      @devices ||= params.require(:devices).map { |device| device.permit(%i[service token environment subscription]) }
    end

    def endpoint(device)
      PushDelivery::Apns.endpoint(token: device.require(:token), environment: device.require(:environment))
    end

    def notification(device)
      PushDelivery::Apns.notification(
        title: params[:title].to_s,
        body: params.require(:body),
        tag: params[:tag].to_s.first(64).presence,
        subscription: device.require(:subscription).to_s.first(36),
        sound: params[:sound] != false
      )
    end

    def apns
      @apns ||= PushDelivery::Apns.new
    end

    def too_many_requests
      render json: { error: 'Too many notifications relayed from this address. The limit resets within the hour.' },
             status: :too_many_requests
    end
  end
end
