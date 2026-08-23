# frozen_string_literal: true

module Locales
  NAMES = {
    en: 'English',
    de: 'Deutsch',
    es: 'Español',
    fr: 'Français',
    it: 'Italiano',
    nl: 'Nederlands',
    pt: 'Português'
  }.freeze

  TAG = /[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*/

  ALTERNATES = (NAMES.keys - [I18n.default_locale]).map(&:to_s).freeze

  module_function

  def resolve(chosen, accept_language)
    available(chosen) || from_header(accept_language) || I18n.default_locale
  end

  def available(tag)
    locale = tag.to_s.split('-').first.to_s.downcase.to_sym

    locale if NAMES.key?(locale)
  end

  def from_header(header)
    header.to_s.scan(TAG).lazy.filter_map { |tag| available(tag) }.first
  end
end
