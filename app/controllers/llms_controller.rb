# frozen_string_literal: true

class LlmsController < WebController
  def show
    head :not_found unless ProgressWatch.multitenant?
  end
end
