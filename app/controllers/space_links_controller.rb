# frozen_string_literal: true

class SpaceLinksController < WebController
  def show
    @space = Space.find(params[:uuid])
  end
end
