# frozen_string_literal: true

class SpacesController < ApplicationController
  def show
    render json: Spaces::SerializeForApi.call(Space.find(params[:uuid]))
  end

  def create
    space = Spaces::Create.call(title: params[:title], icon: params[:icon])

    render json: rendered(space), status: :created
  end

  private

  def rendered(space)
    { uuid: space.uuid, title: space.title, icon: space.icon }
  end
end
