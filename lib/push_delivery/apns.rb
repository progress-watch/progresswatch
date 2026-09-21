# frozen_string_literal: true

require 'httpx'
require 'jwt'

module PushDelivery
  class Apns
    Error = Class.new(StandardError)
    InvalidDevice = Class.new(StandardError)

    HOSTS = { 'production' => 'api.push.apple.com', 'sandbox' => 'api.sandbox.push.apple.com' }.freeze
    TOKEN = /\A\h{64,200}\z/
    GONE_REASONS = %w[BadDeviceToken Unregistered DeviceTokenNotForTopic].freeze
    AUTHORIZATION_LIFETIME = 50.minutes
    TITLE_LIMIT = 200
    BODY_LIMIT = 500

    class << self
      def endpoint(token:, environment:)
        raise InvalidDevice, 'not an APNs device token' unless TOKEN.match?(token.to_s)
        raise InvalidDevice, 'environment is production or sandbox' unless HOSTS.key?(environment.to_s)

        "https://#{HOSTS.fetch(environment.to_s)}/3/device/#{token.downcase}"
      end

      def endpoint?(endpoint)
        HOSTS.value?(URI.parse(endpoint.to_s).host)
      rescue URI::InvalidURIError
        false
      end

      def device(endpoint)
        uri = URI.parse(endpoint)

        { service: 'apns', token: uri.path.split('/').last, environment: HOSTS.key(uri.host) }
      end

      def notification(title:, body:, tag:, subscription:, sound: true)
        alert = { title: title.presence&.first(TITLE_LIMIT) || 'Progress Watch', body: body.to_s.first(BODY_LIMIT) }
        aps = { alert:, 'thread-id': tag }
        aps[:sound] = 'default' if sound

        { aps: aps.compact, subscription: }
      end

      def authorization
        @authorization = nil if @issued_at && @issued_at < AUTHORIZATION_LIFETIME.ago
        @authorization ||= begin
          @issued_at = Time.current
          key = OpenSSL::PKey::EC.new(ProgressWatch::APNS_KEY.gsub('\n', "\n"))

          "bearer #{JWT.encode({ iss: ProgressWatch::APNS_TEAM_ID, iat: @issued_at.to_i }, key, 'ES256',
                               { kid: ProgressWatch::APNS_KEY_ID })}"
        end
      end
    end

    def deliver(subscription, payload)
      notification = self.class.notification(title: payload[:title], body: payload.fetch(:body), tag: payload[:tag],
                                             subscription: subscription.uuid, sound: payload[:renotify])

      PushDelivery.forget(subscription, payload, code: 410) if push(subscription.endpoint, notification) == :gone
    end

    def push(endpoint, notification)
      response = HTTPX.with(headers: headers(notification)).post(endpoint, json: notification)

      raise Error, response.error.message if response.is_a?(HTTPX::ErrorResponse)

      return :ok if response.status == 200

      reason = reason_of(response)

      return :gone if response.status == 410 || GONE_REASONS.include?(reason)

      raise Error, "APNs answered #{response.status} #{reason}"
    end

    private

    def headers(notification)
      {
        'authorization' => self.class.authorization,
        'apns-topic' => ProgressWatch::APNS_TOPIC,
        'apns-push-type' => 'alert',
        'apns-priority' => '10',
        'apns-collapse-id' => notification.dig(:aps, :'thread-id')
      }.compact
    end

    def reason_of(response)
      JSON.parse(response.body.to_s)['reason']
    rescue JSON::ParserError
      nil
    end
  end
end
