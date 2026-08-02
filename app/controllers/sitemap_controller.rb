# frozen_string_literal: true

class SitemapController < WebController
  # head, not the not-found page: this route answers XML to crawlers, and the error page
  # is HTML.
  def show
    head :not_found unless ProgressWatch.multitenant?
  end
end
