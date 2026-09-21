# frozen_string_literal: true

require 'net/http'

module PushDelivery
  class Relay
    Error = Class.new(StandardError)

    PATH = '/relay'

    def deliver(subscription, payload)
      response = Net::HTTP.post(URI.join(ProgressWatch::PUSH_RELAY, PATH), body(subscription, payload).to_json,
                                'Content-Type' => 'application/json')

      case response.code.to_i
      when 200..299 then nil
      when 410 then PushDelivery.forget(subscription, payload, code: 410)
      when 404 then Rails.logger.warn({ event: 'push.relay_unavailable', relay: ProgressWatch::PUSH_RELAY }.to_json)
      else raise Error, "the relay answered #{response.code}"
      end
    end

    private

    def body(subscription, payload)
      {
        service: 'apns',
        **Apns.device(subscription.endpoint),
        title: payload[:title],
        body: payload.fetch(:body),
        tag: payload[:tag],
        sound: payload[:renotify],
        subscription: subscription.uuid
      }
    end
  end
end
