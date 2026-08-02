# frozen_string_literal: true

# Base for the HTML pages. The JSON API keeps its own base (ApplicationController,
# an ActionController::API) so the two never share filters or rescue handlers.
class WebController < ActionController::Base
  # Named explicitly. Implicit lookup walks controller names and would silently
  # render these pages with no layout at all — no stylesheet, no JavaScript — which
  # is exactly what happened before this line existed.
  layout 'application'

  protect_from_forgery with: :exception

  private

  # A space UUID is a credential, so a mistyped one has to look the same as one that
  # was never created — no "this space exists but you may not see it" distinction to
  # probe at, because there is no such distinction to make.
  def find_space
    Space.find_by(uuid: params[:uuid]) || not_found
  end

  def not_found
    render 'pages/not_found', status: :not_found

    nil
  end
end
