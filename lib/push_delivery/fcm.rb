# frozen_string_literal: true

module PushDelivery
  class Fcm
    InvalidDevice = Class.new(StandardError)

    SCHEME = 'fcm:'
    TOKEN = /\A[\w:-]{32,4096}\z/

    class << self
      def endpoint(token:)
        raise InvalidDevice, 'not an FCM registration token' unless TOKEN.match?(token.to_s)

        "#{SCHEME}#{token}"
      end

      def endpoint?(endpoint)
        endpoint.to_s.start_with?(SCHEME)
      end

      def device(endpoint)
        { service: 'fcm', token: endpoint.delete_prefix(SCHEME) }
      end
    end
  end
end
