# frozen_string_literal: true

class DocsController < WebController
  def index; end

  def show
    @section = params[:section]
    @doc = Docs::DOCUMENTS.find { |doc| doc[:slug] == @section }

    return not_found unless @doc || ConnectSnippets::SECTIONS.key?(@section)

    @space_uuid = params[:space].presence
  end
end
