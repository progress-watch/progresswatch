# frozen_string_literal: true

class ApiDocsController < WebController
  def default_url_options
    { locale: (I18n.locale unless I18n.locale == I18n.default_locale) }
  end

  def index
    @operations = OpenApi::Operations.call
  end
end
