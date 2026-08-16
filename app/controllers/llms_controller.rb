# frozen_string_literal: true

class LlmsController < WebController
  # head, not the not-found page: this route answers plain text, and the error page is
  # HTML.
  def show
    head :not_found unless ProgressWatch.multitenant?
  end
end
