# frozen_string_literal: true

class SitemapController < WebController
  def show
    head :not_found unless ProgressWatch.multitenant?
  end
end
