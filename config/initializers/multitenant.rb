# frozen_string_literal: true

module ProgressWatch
  # The hosted service, as opposed to somebody's own box. Everything written for a
  # stranger who found us in a search — the about page, the sitemap, any indexing at all
  # — belongs to that one deployment. A self-hosted instance has no audience to reach and
  # nothing it wants a crawler to see.
  def self.multitenant?
    ENV['MULTITENANT'] == 'true'
  end
end
