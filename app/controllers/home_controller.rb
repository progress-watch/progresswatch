# frozen_string_literal: true

class HomeController < WebController
  def show
    render 'docs/index' if markdown?
  end
end
