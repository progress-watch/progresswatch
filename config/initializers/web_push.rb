# frozen_string_literal: true

module ProgressWatch
  VAPID_PUBLIC_KEY = ENV.fetch('VAPID_PUBLIC_KEY', nil)
  VAPID_PRIVATE_KEY = ENV.fetch('VAPID_PRIVATE_KEY', nil)
  VAPID_SUBJECT = ENV.fetch('VAPID_SUBJECT', 'mailto:hello@progress.watch')

  def self.web_push?
    VAPID_PUBLIC_KEY.present? && VAPID_PRIVATE_KEY.present?
  end
end

Rails.application.config.to_prepare do
  PushDelivery.backend = PushDelivery::WebPush.new if ProgressWatch.web_push?
end
