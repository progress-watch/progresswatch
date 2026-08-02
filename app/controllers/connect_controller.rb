# frozen_string_literal: true

class ConnectController < WebController
  def show
    @section = params[:section]

    return not_found unless ConnectSnippets::SECTIONS.key?(@section)

    @space_uuid = params[:space].presence
    @snippet_uuid = @space_uuid || ConnectSnippets::PLACEHOLDER
  end
end
