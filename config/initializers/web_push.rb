# frozen_string_literal: true

# Read at boot, like MULTITENANT: a running server does not pick up new keys until it
# restarts. Absent keys mean the feature is simply not offered — the button never
# renders and nothing is stored about anyone.
module ProgressWatch
  VAPID_PUBLIC_KEY = ENV.fetch('VAPID_PUBLIC_KEY', nil)
  VAPID_PRIVATE_KEY = ENV.fetch('VAPID_PRIVATE_KEY', nil)
  VAPID_SUBJECT = ENV.fetch('VAPID_SUBJECT', 'mailto:hello@progress.watch')

  def self.web_push?
    VAPID_PUBLIC_KEY.present? && VAPID_PRIVATE_KEY.present?
  end
end

# to_prepare, not here at the top level: PushDelivery is autoloaded from lib, and
# referencing an autoloadable constant while Rails initializes raises. It only ever
# raised once the keys were set, so the failure arrived with the feature rather than
# with the code.
Rails.application.config.to_prepare do
  PushDelivery.backend = PushDelivery::WebPush.new if ProgressWatch.web_push?
end
