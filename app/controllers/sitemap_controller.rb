# frozen_string_literal: true

class SitemapController < WebController
  def show
    @urls = [root_url, *ConnectSnippets::SECTIONS.each_key.map { |section| connect_url(section) }]
  end
end
