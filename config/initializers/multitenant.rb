# frozen_string_literal: true

module ProgressWatch
  REPOSITORY_URL = 'https://github.com/progress-watch/progresswatch'

  def self.multitenant?
    ENV['MULTITENANT'] == 'true'
  end
end
