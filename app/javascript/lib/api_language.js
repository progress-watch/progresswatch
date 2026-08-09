import { readSetting, writeSetting } from './profile'

const SETTING = 'api_language'
const PARAM = 'lang'

export function readLanguage (fallback) {
  return readSetting(SETTING, fallback)
}

export function writeLanguage (language) {
  const url = new URL(window.location.href)

  writeSetting(SETTING, language)
  url.searchParams.set(PARAM, language)
  window.history.replaceState({}, '', url)
}

export function applyLink () {
  const language = new URLSearchParams(window.location.search).get(PARAM)
  if (!language || !document.querySelector(`[data-language="${CSS.escape(language)}"]`)) return

  writeSetting(SETTING, language)
}
