# frozen_string_literal: true

module PushDelivery
  class WebPush
    InvalidEndpoint = Class.new(StandardError)

    GONE = [404, 410].freeze
    ENDPOINT_LIMIT = 2048
    LOCAL_HOSTS = /\A(localhost|.*\.localhost|.*\.local|.*\.internal)\z/i

    def self.endpoint(url)
      raise InvalidEndpoint, 'endpoint is too long' if url.to_s.length > ENDPOINT_LIMIT

      uri = URI.parse(url.to_s)
      raise InvalidEndpoint, 'not an https push endpoint' unless uri.is_a?(URI::HTTPS) && uri.host.present?
      raise InvalidEndpoint, 'not a push service' if address?(uri.host) || LOCAL_HOSTS.match?(uri.host)
      raise InvalidEndpoint, 'not a browser endpoint' if Apns.endpoint?(url) || Fcm.endpoint?(url)

      url.to_s
    rescue URI::InvalidURIError
      raise InvalidEndpoint, 'not an https push endpoint'
    end

    def self.address?(host)
      IPAddr.new(host.delete_prefix('[').delete_suffix(']'))
      true
    rescue IPAddr::InvalidAddressError
      false
    end

    def deliver(subscription, payload)
      ::WebPush.payload_send(
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
        message: message(payload).to_json,
        vapid: {
          subject: ProgressWatch::VAPID_SUBJECT,
          public_key: ProgressWatch::VAPID_PUBLIC_KEY,
          private_key: ProgressWatch::VAPID_PRIVATE_KEY
        }
      )
    rescue ::WebPush::ResponseError => e
      raise unless GONE.include?(e.response.code.to_i)

      PushDelivery.forget(subscription, payload, code: e.response.code.to_i)
    end

    private

    def message(payload)
      {
        title: payload[:title].presence || 'Progress Watch',
        body: payload.fetch(:body),
        tag: payload[:tag],
        renotify: payload[:renotify],
        url: "/s/#{payload.fetch(:space_uuid)}"
      }
    end
  end
end
