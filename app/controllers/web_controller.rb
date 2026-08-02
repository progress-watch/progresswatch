# frozen_string_literal: true

class WebController < ActionController::Base
  # Implicit lookup walks controller names and silently renders with no layout at all.
  layout 'application'

  protect_from_forgery with: :exception

  helper_method :turbo_frame_request?, :svg_icon

  rescue_from ActiveRecord::RecordNotFound do
    not_found(
      heading: 'No such space',
      explanation: 'Either the UUID is wrong, or this server has never heard of it. A space created on ' \
                   'one server does not exist on another — check which server you are on.'
    )
  end

  private

  # render_to_string, not render: helper_method proxies to the controller, where `render`
  # would mean the response.
  def svg_icon(name, **attributes)
    render_to_string(partial: "icons/#{name}", locals: { attributes: attributes })
  end

  # turbo-rails is not a dependency — Turbo is the npm package — so the one helper of
  # its we actually use is spelled out here.
  def turbo_frame_request?
    request.headers['Turbo-Frame'].present?
  end

  def not_found(heading: nil, explanation: nil)
    render 'errors/not_found', status: :not_found, locals: { heading:, explanation: }
  end
end
