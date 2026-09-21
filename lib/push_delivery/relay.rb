# frozen_string_literal: true

require 'net/http'

module PushDelivery
  class Relay
    Error = Class.new(StandardError)

    BATCH = 100

    def deliver(subscriptions, payload)
      subscriptions.each_slice(BATCH) { |batch| send_batch(batch, payload) }
    end

    private

    def send_batch(subscriptions, payload)
      response = Net::HTTP.post(URI.join(ProgressWatch::PUSH_RELAY, '/relay'), body(subscriptions, payload).to_json,
                                'Content-Type' => 'application/json')

      case response.code.to_i
      when 200..299 then settle(subscriptions, JSON.parse(response.body), payload)
      when 404 then unavailable(subscriptions.size)
      else raise Error, "the relay answered #{response.code}"
      end
    end

    def settle(subscriptions, answer, payload)
      subscriptions.select { |subscription| answer.fetch('gone').include?(subscription.uuid) }
                   .each { |subscription| PushDelivery.forget(subscription, payload, code: 410) }

      unavailable(answer.fetch('unavailable').size) if answer.fetch('unavailable').any?
    end

    def unavailable(devices)
      Rails.logger.warn({ event: 'push.relay_unavailable', relay: ProgressWatch::PUSH_RELAY, devices: }.to_json)
    end

    def body(subscriptions, payload)
      {
        title: payload[:title],
        body: payload.fetch(:body),
        tag: payload[:tag],
        sound: payload[:renotify],
        devices: subscriptions.map do |subscription|
          { **(subscription.fcm? ? Fcm : Apns).device(subscription.endpoint), subscription: subscription.uuid }
        end
      }
    end
  end
end
