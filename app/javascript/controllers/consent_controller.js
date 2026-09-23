import { Controller } from "@hotwired/stimulus"

// "Setări cookie-uri" in the footer: forgets the stored choice so the notice
// (shared/_gdpr) is rendered again on the next page load.
export default class extends Controller {
  reopen(event) {
    event.preventDefault()
    document.cookie = "cookie_consent=; path=/; max-age=0"
    window.location.reload()
  }
}
