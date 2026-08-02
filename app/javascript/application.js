import '@hotwired/turbo'

import { remember } from './lib/profile'

import ClipboardCopy from './elements/clipboard_copy'
import ForgetSpace from './elements/forget_space'
import IconInput from './elements/icon_input'
import ModalButton from './elements/modal_button'
import OpenSpace from './elements/open_space'
import PollFrame from './elements/poll_frame'
import SpaceList from './elements/space_list'
import SpaceBackup from './elements/space_backup'
import SpaceRouter from './elements/space_router'
import StickyDetails from './elements/sticky_details'
import TabPanels from './elements/tab_panels'

import './application.scss'

// Turbo caches pages and replays them, so an element can be defined twice on the
// way back through history.
function safeRegisterElement (name, elementClass) {
  if (!window.customElements.get(name)) window.customElements.define(name, elementClass)
}

safeRegisterElement('clipboard-copy', ClipboardCopy)
safeRegisterElement('forget-space', ForgetSpace)
safeRegisterElement('icon-input', IconInput)
safeRegisterElement('modal-button', ModalButton)
safeRegisterElement('open-space', OpenSpace)
safeRegisterElement('poll-frame', PollFrame)
safeRegisterElement('space-list', SpaceList)
safeRegisterElement('space-backup', SpaceBackup)
safeRegisterElement('space-router', SpaceRouter)
safeRegisterElement('sticky-details', StickyDetails)
safeRegisterElement('tab-panels', TabPanels)

// Records the space in this browser the moment its dashboard is opened, so pasting a
// UUID someone shared is all it takes to keep it.
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
