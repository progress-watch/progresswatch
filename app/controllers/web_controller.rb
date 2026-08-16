# frozen_string_literal: true

class WebController < ActionController::Base
  # Implicit lookup walks controller names and silently renders with no layout at all.
  layout 'application'

  protect_from_forgery with: :exception

  helper_method :turbo_frame_request?, :frame_id, :svg_icon

  # Real view helpers and not helper_method: capture and content_for both work against
  # the state of the view that is rendering, and helper_method runs on the controller.
  helper do
    def markdown(&)
      Kramdown::Document.new(capture(&)).to_html.html_safe # rubocop:disable Rails/OutputSafety
    end

    # A page opting in is half of it: nothing on a self-hosted box is meant to be found
    # from outside, so the flag is checked here rather than at each of the places that
    # emit something only an indexable page should have.
    def indexable?
      content_for?(:indexable) && ProgressWatch.multitenant?
    end
  end

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

  # The history chain asks from a different frame at every page, so the response cannot
  # name one in the template.
  def frame_id
    request.headers['Turbo-Frame']
  end

  def not_found(heading: nil, explanation: nil)
    render 'errors/not_found', status: :not_found, locals: { heading:, explanation: }
  end
end
