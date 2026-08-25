# frozen_string_literal: true

class OpenApiController < ApplicationController
  def show
    specs = OpenApi.call(base_url: request.base_url)

    if request.format.yaml?
      render plain: specs.to_yaml, content_type: 'text/yaml'
    else
      render json: specs
    end
  end
end
