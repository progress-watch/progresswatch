# frozen_string_literal: true

class DocsController < WebController
  before_action :refuse_translated_markdown

  def default_url_options
    { locale: (I18n.locale unless I18n.locale == I18n.default_locale) }
  end

  def index; end

  def show
    @section = params[:section]
    @doc = Docs::DOCUMENTS.find { |doc| doc[:slug] == @section }

    return not_found unless @doc || ConnectSnippets::SECTIONS.key?(@section)

    @space_uuid = params[:space].presence
  end

  private

  def refuse_translated_markdown
    head :not_found if markdown? && params[:locale]
  end
end
