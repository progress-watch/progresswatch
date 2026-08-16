# frozen_string_literal: true

module Api
  class SpacesController < ApplicationController
    def show
      space = Space.find(params[:uuid])
      window = params.permit(:before, :after, :limit)

      render json: Spaces::SerializeForApi.call(space, before: window[:before], after: window[:after],
                                                       limit: window[:limit])
    rescue Spaces::ReadTasks::InvalidWindow => e
      render json: { error: e.message }, status: :bad_request
    end

    def create
      RateLimit.call(request.remote_ip)

      space = Spaces::Create.call(title: params[:title], icon: params[:icon])

      render json: rendered(space), status: :created
    end

    private

    def rendered(space)
      { uuid: space.uuid, title: space.title, icon: space.icon }
    end
  end
end
