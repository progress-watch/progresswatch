# frozen_string_literal: true

class RobotsController < WebController
  def show
    render plain: ProgressWatch.multitenant? ? hosted : self_hosted
  end

  private

  def hosted
    <<~TXT
      User-agent: *
      Disallow: /s/
      Disallow: /spaces
      Disallow: /tasks
      Disallow: /mcp

      Sitemap: #{sitemap_url}
    TXT
  end

  def self_hosted
    <<~TXT
      User-agent: *
      Disallow: /
    TXT
  end
end
