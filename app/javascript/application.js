import '@hotwired/turbo'

import { remember } from './lib/profile'

import AddSpace from './elements/add_space'
import ClipboardCopy from './elements/clipboard_copy'
import CodeSamples from './elements/code_samples'
import DropdownMenu from './elements/dropdown_menu'
import ForgetSpace from './elements/forget_space'
import IconInput from './elements/icon_input'
import TurboModal from './elements/turbo_modal'
import PollFrame from './elements/poll_frame'
import PushToggle from './elements/push_toggle'
import SpaceList from './elements/space_list'
import SpaceBackup from './elements/space_backup'
import ThemeToggle from './elements/theme_toggle'
import StickyDetails from './elements/sticky_details'
import TabPanels from './elements/tab_panels'

import './application.scss'

// Turbo caches pages and replays them, so an element can be defined twice on the
// way back through history.
function safeRegisterElement (name, elementClass) {
  if (!window.customElements.get(name)) window.customElements.define(name, elementClass)
}

safeRegisterElement('add-space', AddSpace)
safeRegisterElement('clipboard-copy', ClipboardCopy)
safeRegisterElement('code-samples', CodeSamples)
safeRegisterElement('dropdown-menu', DropdownMenu)
safeRegisterElement('forget-space', ForgetSpace)
safeRegisterElement('icon-input', IconInput)
safeRegisterElement('turbo-modal', TurboModal)
safeRegisterElement('poll-frame', PollFrame)
safeRegisterElement('theme-toggle', ThemeToggle)
safeRegisterElement('push-toggle', PushToggle)
safeRegisterElement('space-list', SpaceList)
safeRegisterElement('space-backup', SpaceBackup)
safeRegisterElement('sticky-details', StickyDetails)
safeRegisterElement('tab-panels', TabPanels)

safeRegisterElement('remember-space', class extends HTMLElement {
  connectedCallback () {
    remember({
      uuid: this.dataset.uuid,
      title: this.dataset.title || null,
      icon: this.dataset.icon || null,
      server: this.dataset.server
    })
  }
})
