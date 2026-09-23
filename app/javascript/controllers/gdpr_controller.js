import { Controller } from "@hotwired/stimulus"

// Cookie consent. The choice lives in the cookie_consent cookie so the server
// can read it: with "all" the layout renders the Google and Meta tags and Ahoy
// may open a visit, with "essential" neither happens.
//
// Both buttons reload the page once, so the tags start (or stop) on a clean
// page instead of being injected halfway through.
const COOKIE = "cookie_consent"
const YEAR = 365 * 24 * 60 * 60

export default class extends Controller {
  static targets = ["acceptModal"]

  connect() {
    this.acceptModalTarget.style.display = "block"
  }

  acceptAll() {
    this.#save("all")
  }

  rejectAll() {
    this.#deleteTrackingCookies()
    this.#save("essential")
  }

  #save(value) {
    const secure = window.location.protocol === "https:" ? "; secure" : ""
    document.cookie = `${COOKIE}=${value}; path=/; max-age=${YEAR}; samesite=lax${secure}`
    this.acceptModalTarget.style.display = "none"
    window.location.reload()
  }

  // Cookies a previous visit may have left behind. Google and Meta set theirs
  // on this domain, so they can be removed here; anything on their own domains
  // is out of reach and is covered by the browser settings note in the text.
  #deleteTrackingCookies() {
    const names = document.cookie
      .split("; ")
      .map((c) => c.split("=")[0])
      .filter((n) => /^(_ga|_gid|_gcl|_fbp|_fbc|ahoy_)/.test(n))
    const host = window.location.hostname
    const domains = [host, `.${host}`, `.${host.split(".").slice(-2).join(".")}`]
    names.forEach((name) => {
      domains.forEach((domain) => {
        document.cookie = `${name}=; path=/; domain=${domain}; max-age=0`
      })
      document.cookie = `${name}=; path=/; max-age=0`
    })
  }
}
