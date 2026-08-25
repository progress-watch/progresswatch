import { readSetting, writeSetting } from './profile'

const SETTING = 'theme'
const CHANGED = 'theme:changed'

export const THEMES = ['system', 'light', 'dark']

export function readTheme () {
  const stored = readSetting(SETTING, 'system')

  return THEMES.includes(stored) ? stored : 'system'
}

export function applyTheme (theme = readTheme()) {
  if (theme === 'system') {
    document.documentElement.removeAttribute('data-theme')
  } else {
    document.documentElement.setAttribute('data-theme', theme)
  }
}

export function writeTheme (theme) {
  writeSetting(SETTING, theme)
  applyTheme(theme)
  document.dispatchEvent(new CustomEvent(CHANGED))
}

export function onThemeChange (handler) {
  document.addEventListener(CHANGED, handler)

  return () => document.removeEventListener(CHANGED, handler)
}
