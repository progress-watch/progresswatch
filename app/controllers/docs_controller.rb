# frozen_string_literal: true

class DocsController < WebController
  def index; end

  def show
    @section = params[:section]

    return not_found unless ConnectSnippets::SECTIONS.key?(@section)

    @space_uuid = params[:space].presence
  end
end
