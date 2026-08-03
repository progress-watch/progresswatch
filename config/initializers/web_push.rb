# frozen_string_literal: true

# Absent keys mean the feature is not offered at all.
module ProgressWatch
  VAPID_PUBLIC_KEY = ENV.fetch('VAPID_PUBLIC_KEY', nil)
  VAPID_PRIVATE_KEY = ENV.fetch('VAPID_PRIVATE_KEY', nil)
  VAPID_SUBJECT = ENV.fetch('VAPID_SUBJECT', 'mailto:hello@progress.watch')

  def self.web_push?
    VAPID_PUBLIC_KEY.present? && VAPID_PRIVATE_KEY.present?
  end
end

# to_prepare: PushDelivery is autoloaded, and autoloading during initialization raises.
Rails.application.config.to_prepare do
  PushDelivery.backend = PushDelivery::WebPush.new if ProgressWatch.web_push?
end
