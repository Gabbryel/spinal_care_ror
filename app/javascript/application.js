import "@hotwired/turbo-rails"
import ahoy from "ahoy.js"
import "./controllers"
import "bootstrap"
// import "trix"
import "@rails/actiontext"

// Ahoy is bundled (it used to be a render-blocking CDN script in <head>).
// Its defaults are /ahoy/visits and /ahoy/events; it starts on the next
// tick, after this module has run.
// The bundle also runs on /dashboard pages, which were never tracked: no
// visit is started there.
// Analytics runs only for visitors who accepted it (shared/_gdpr writes the
// cookie_consent cookie; the server checks the same value before letting Ahoy
// open a visit).
const isAdminPage = () => window.location.pathname.startsWith("/dashboard")
const trackingAllowed = () => document.cookie.split("; ").includes("cookie_consent=all")
ahoy.configure({ visitsUrl: "/ahoy/visits", eventsUrl: "/ahoy/events", startOnReady: false })

// One gate for every caller (click-tracker, engagement, search): without
// consent an event would still reach /ahoy/events and open a visit there.
const track = ahoy.track.bind(ahoy)
ahoy.track = (...args) => { if (trackingAllowed()) track(...args) }
window.ahoy = ahoy

// One $view per page shown: turbo:load fires once for the initial page and
// after every Turbo Drive navigation. ahoy.start() is a no-op once started.
document.addEventListener("turbo:load", () => {
  if (isAdminPage() || !trackingAllowed()) return
  ahoy.start()
  ahoy.trackView()
})
