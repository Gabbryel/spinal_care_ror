import { Controller } from "@hotwired/stimulus"

// The questionnaire invitation (surveys/_feedback_popup). The delay counts
// from the first page of the visit, not from each page: the start time lives
// in sessionStorage, so a visitor who moves on after 15 seconds sees it 5
// seconds into the next page. Shown at most once per browser session, and
// held back while the booking window or the cookie notice is open.
// sessionStorage keeps nothing after the tab closes and is never sent to the
// server; if it is unavailable the invitation simply does not show.
const START = "feedbackPopupStart"
const DONE = "feedbackPopupDone"
const RETRY = 5000
const MIN_ON_PAGE = 2000

export default class extends Controller {
  static values = { delay: Number }

  connect() {
    try {
      if (sessionStorage.getItem(DONE)) return
      let start = Number(sessionStorage.getItem(START))
      if (!start) {
        start = Date.now()
        sessionStorage.setItem(START, String(start))
      }
      const remaining = this.delayValue - (Date.now() - start)
      this.schedule(Math.max(remaining, MIN_ON_PAGE))
    } catch (e) {
      // Storage blocked (private mode, strict settings): no invitation.
    }
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  schedule(ms) {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.show(), ms)
  }

  show() {
    if (this.busy()) return this.schedule(RETRY)
    try { sessionStorage.setItem(DONE, "1") } catch (e) {}
    this.element.hidden = false
    requestAnimationFrame(() => this.element.classList.add("is-open"))
    this.track("shown")
  }

  close() {
    if (this.element.hidden) return
    this.element.classList.remove("is-open")
    this.element.hidden = true
    this.track("closed")
  }

  accept() {
    this.track("clicked")
  }

  // Never on top of the booking window or the cookie notice.
  busy() {
    if (document.querySelector(".modal.show")) return true
    const consent = document.querySelector('[data-gdpr-target="acceptModal"]')
    // offsetParent is always null for a fixed element, so read the style.
    return Boolean(consent && getComputedStyle(consent).display !== "none")
  }

  // Through the consent-gated ahoy.track (application.js): nothing is sent
  // for visitors who refused analytics.
  track(action) {
    window.ahoy?.track("$feedback_popup", { action, page: window.location.pathname })
  }
}
