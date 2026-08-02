# frozen_string_literal: true

class PagesController < WebController
  def index; end

  def connect
    @section = params[:section]
    @space_uuid = params[:space].presence || ConnectSnippets::PLACEHOLDER
  end
end
