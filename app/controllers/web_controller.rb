# frozen_string_literal: true

class WebController < ActionController::Base
  layout -> { markdown? ? false : 'application' }

  protect_from_forgery with: :exception

  around_action :with_locale

  helper_method :turbo_frame_request?, :frame_id, :svg_icon, :locale_url, :translated?, :translations,
                :docs_locale, :switch_to

  helper do
    def indexable?
      content_for?(:indexable) && ProgressWatch.multitenant?
    end
  end

  rescue_from ActiveRecord::RecordNotFound do
    I18n.with_locale(locale) do
      not_found(heading: t('no_such_space'),
                explanation: t('either_the_uuid_is_wrong_or_this_server_has_never_heard_of_it'))
    end
  end

  private

  def with_locale(&)
    I18n.with_locale(locale, &)
  end

  def locale_url(locale)
    url_for(only_path: false, locale: (locale if translated? && locale != I18n.default_locale))
  end

  def translated?
    request.route_uri_pattern.to_s.include?(':locale')
  end

  def translations(*keys)
    keys.index_with { |key| t(key) }.to_json
  end

  def locale
    @locale ||= begin
      chosen = Locales.available(params[:locale])

      cookies[:locale] = { value: chosen, expires: 1.year.from_now, same_site: :lax } if chosen

      if markdown?
        I18n.default_locale
      elsif translated?
        chosen || I18n.default_locale
      else
        Locales.resolve(chosen || cookies[:locale], request.headers['Accept-Language'])
      end
    end
  end

  def switch_to(locale)
    query = request.query_parameters

    return url_for(query.merge(locale:, only_path: true)) unless translated? && locale == I18n.default_locale

    "#{url_for(query.merge(locale: nil, only_path: true))}#{query.any? ? '&' : '?'}locale=#{locale}"
  end

  def docs_locale
    I18n.locale unless I18n.locale == I18n.default_locale
  end

  def markdown?
    request.format.md?
  end

  def svg_icon(name, **attributes)
    render_to_string(partial: "icons/#{name}", locals: { attributes: attributes })
  end

  def turbo_frame_request?
    request.headers['Turbo-Frame'].present?
  end

  def frame_id
    request.headers['Turbo-Frame']
  end

  def not_found(heading: nil, explanation: nil)
    return head :not_found if markdown?

    render 'errors/not_found', status: :not_found, locals: { heading:, explanation: }
  end
end
