import { Controller } from "@hotwired/stimulus";

// Records the clicks that matter (calls, booking button, email, WhatsApp,
// social, map, navigation and external links) as Ahoy "$click" events.
//
// The document listener is bound once per page load, not once per Turbo
// visit: this controller lives on <body>, which Turbo replaces on every
// navigation, and re-binding on each connect() stored the same click up to
// eight times.
//
// The categories must stay in sync with the SQL backfill in
// db/migrate/*_clean_up_click_events.rb and CLICK_CATEGORY_LABELS in
// AdminController.
const SOCIAL_HOSTS = /facebook\.com|instagram\.com|tiktok\.com|youtube\.com|linkedin\.com/i;
const MAP_HOSTS = /maps\.google|google\.[a-z.]+\/maps|goo\.gl\/maps|maps\.app\.goo\.gl|waze\.com/i;
const BOOKING_HOST = /programari\.spinalcare\.ro/i;
const BOOKING_BUTTON = '[data-bs-target="#promoModal"], [data-track="booking"]';
const BOOKING_MODAL_DESTINATION = "programari.spinalcare.ro (modal)";

export default class extends Controller {
  connect() {
    if (document.clickTrackerBound) return;
    document.clickTrackerBound = true;
    // Capture phase: some handlers stop propagation (Bootstrap modal
    // buttons, the side menu), which would hide the click from a bubbling
    // listener.
    document.addEventListener("click", (event) => this.handleClick(event), true);
  }

  handleClick(event) {
    const element = event.target.closest("a, button");
    if (!element || this.isAdminElement(element)) return;

    const click = this.classify(element);
    if (!click || !window.ahoy) return;

    const labelled = element.closest("[data-track-label]");
    ahoy.track("$click", {
      category: click.category,
      destination: click.destination,
      label: labelled ? labelled.dataset.trackLabel.slice(0, 100) : undefined,
      element_type: element.tagName === "A" ? "link" : "button",
      text: element.textContent.trim().replace(/\s+/g, " ").substring(0, 100),
      element_id: element.id,
      classes: element.className,
      section: this.sectionOf(element),
      page: window.location.pathname,
      timestamp: new Date().toISOString(),
    });
  }

  // Returns { category, destination } or null for clicks we do not record
  // (cookie banner, modal close, menu toggles, empty anchors).
  classify(element) {
    if (element.matches(BOOKING_BUTTON) || element.closest(BOOKING_BUTTON)) {
      return { category: "booking", destination: BOOKING_MODAL_DESTINATION };
    }

    const href = element.getAttribute("href");
    if (!href || href === "#" || href.startsWith("javascript:")) return null;

    if (/^tel:/i.test(href)) return { category: "call", destination: href };
    if (/^mailto:/i.test(href)) return { category: "email", destination: href };

    const url = element.href;
    if (/wa\.me|whatsapp/i.test(url)) return { category: "whatsapp", destination: url };
    if (SOCIAL_HOSTS.test(url)) return { category: "social", destination: url };
    if (MAP_HOSTS.test(url)) return { category: "map", destination: url };
    if (BOOKING_HOST.test(url)) return { category: "booking", destination: url };

    let host;
    try {
      host = new URL(url).hostname;
    } catch {
      return null;
    }
    const category = host === window.location.hostname ? "nav" : "external";
    return { category, destination: url };
  }

  sectionOf(element) {
    const landmark = element.closest("header, nav, footer, aside, main, .modal");
    if (!landmark) return "body";
    return landmark.classList.contains("modal") ? "modal" : landmark.tagName.toLowerCase();
  }

  isAdminElement(element) {
    const href = element.href || "";
    return (
      window.location.pathname.startsWith("/dashboard") ||
      href.includes("/dashboard") ||
      href.includes("/admin") ||
      href.includes("/users/sign") ||
      element.closest("[data-no-track]") ||
      element.closest(".analytics-page-enhanced")
    );
  }
}
