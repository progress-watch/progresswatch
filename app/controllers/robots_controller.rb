# frozen_string_literal: true

class RobotsController < WebController
  def show
    render plain: <<~TXT
      User-agent: *
      Disallow: /s/
      Disallow: /spaces
      Disallow: /tasks
      Disallow: /mcp

      Sitemap: #{sitemap_url}
    TXT
  end
end
