# frozen_string_literal: true

class OpenApiController < ApplicationController
  def show
    specs = OpenApi.call(base_url: request.base_url)

    if request.format.yaml?
      # text/yaml and not the registered application/yaml: we send nosniff, and Chrome
      # downloads a type it has no viewer for rather than showing it.
      render plain: specs.to_yaml, content_type: 'text/yaml'
    else
      render json: specs
    end
  end
end
