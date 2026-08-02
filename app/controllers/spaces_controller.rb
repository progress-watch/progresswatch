# frozen_string_literal: true

class SpacesController < ApplicationController
  def show
    render json: Spaces::SerializeForApi.call(Space.find(params[:uuid]))
  end

  def create
    space = Spaces::Create.call(title: params[:title])

    render json: { uuid: space.uuid, title: space.title }, status: :created
  end
end
