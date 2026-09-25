# frozen_string_literal: true

module ProgressWatch
  REPOSITORY_URL = 'https://github.com/progress-watch/progresswatch'
  IOS_APP_ID = ENV.fetch('IOS_APP_ID', nil)

  def self.multitenant?
    ENV['MULTITENANT'] == 'true'
  end
end
