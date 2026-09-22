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
const isAdminPage = () => window.location.pathname.startsWith("/dashboard")
ahoy.configure({ visitsUrl: "/ahoy/visits", eventsUrl: "/ahoy/events", startOnReady: !isAdminPage() })
window.ahoy = ahoy

// One $view per page shown: turbo:load fires once for the initial page and
// after every Turbo Drive navigation. ahoy.start() is a no-op once started.
document.addEventListener("turbo:load", () => {
  if (isAdminPage()) return
  ahoy.start()
  ahoy.trackView()
})
