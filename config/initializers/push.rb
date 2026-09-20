# frozen_string_literal: true

module ProgressWatch
  VAPID_PUBLIC_KEY = ENV.fetch('VAPID_PUBLIC_KEY', nil)
  VAPID_PRIVATE_KEY = ENV.fetch('VAPID_PRIVATE_KEY', nil)
  VAPID_SUBJECT = ENV.fetch('VAPID_SUBJECT', REPOSITORY_URL)

  APNS_KEY = ENV.fetch('APNS_KEY', nil)
  APNS_KEY_ID = ENV.fetch('APNS_KEY_ID', nil)
  APNS_TEAM_ID = ENV.fetch('APNS_TEAM_ID', nil)
  APNS_TOPIC = ENV.fetch('APNS_TOPIC', 'watch.progress.app')
  PUSH_RELAY = ENV.fetch('PUSH_RELAY', 'https://progress.watch')

  def self.web_push?
    VAPID_PUBLIC_KEY.present? && VAPID_PRIVATE_KEY.present?
  end

  def self.apns?
    APNS_KEY.present? && APNS_KEY_ID.present? && APNS_TEAM_ID.present?
  end

  def self.push_relay?
    !apns? && !multitenant? && PUSH_RELAY != 'false'
  end

  def self.native_push?
    apns? || push_relay?
  end
end

Rails.application.config.to_prepare do
  PushDelivery.backend = PushDelivery::Subscribers.new if ProgressWatch.web_push? || ProgressWatch.native_push?
end
