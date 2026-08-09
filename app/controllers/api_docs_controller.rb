# frozen_string_literal: true

class ApiDocsController < WebController
  def index
    @operations = OpenApi::Operations.call
  end
end
