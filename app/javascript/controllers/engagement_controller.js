import { Controller } from "@hotwired/stimulus";

// Per-page engagement, sent to Ahoy when the visitor leaves the page:
//   $leave        { page, seconds, depth, cta_present, cta_seen }
//   $section_view { page, section }   once per price-list section scrolled into view
//   $booking      { step, page, ... } relayed from the booking site's iframe (postMessage)
//
// Lives on <body>, so Turbo replaces it on every navigation: connect() starts
// a page, disconnect() closes it. Time counts only while the tab is visible.
//
// Booking site contract (programari.spinalcare.ro): from inside the iframe,
//   window.parent.postMessage({ type: "spinalcare:booking", step: "started" | "completed", service: "...", doctor: "..." }, "https://www.spinalcare.ro")
const BOOKING_ORIGINS = ["https://programari.spinalcare.ro", "https://www.programari.spinalcare.ro"];
const DEPTHS = [25, 50, 75, 100];

export default class extends Controller {
  connect() {
    this.page = window.location.pathname;
    this.activeSince = document.hidden ? null : Date.now();
    this.seconds = 0;
    this.depth = 0;
    this.sent = false;
    this.seenSections = new Set();

    this.onScroll = () => this.measureDepth();
    this.onVisibility = () => this.visibilityChanged();
    this.onPageHide = () => this.leave();
    this.onMessage = (event) => this.bookingMessage(event);
    window.addEventListener("scroll", this.onScroll, { passive: true });
    document.addEventListener("visibilitychange", this.onVisibility);
    window.addEventListener("pagehide", this.onPageHide);
    window.addEventListener("message", this.onMessage);

    this.observeCta();
    this.observeSections();
    this.measureDepth();
  }

  disconnect() {
    this.leave();
    window.removeEventListener("scroll", this.onScroll);
    document.removeEventListener("visibilitychange", this.onVisibility);
    window.removeEventListener("pagehide", this.onPageHide);
    window.removeEventListener("message", this.onMessage);
    if (this.ctaObserver) this.ctaObserver.disconnect();
    if (this.sectionObserver) this.sectionObserver.disconnect();
  }

  // --- time -----------------------------------------------------------

  visibilityChanged() {
    if (document.hidden) {
      this.leave();
    } else {
      // Back on the page: start a new stretch (a second $leave for the same
      // page view; the analysis sums seconds and keeps the max depth).
      this.activeSince = Date.now();
      this.seconds = 0;
      this.sent = false;
    }
  }

  activeSeconds() {
    if (this.activeSince) {
      this.seconds += (Date.now() - this.activeSince) / 1000;
      this.activeSince = null;
    }
    return Math.min(Math.round(this.seconds), 1800);
  }

  // --- scroll depth -----------------------------------------------------

  measureDepth() {
    const doc = document.documentElement;
    const scrollable = doc.scrollHeight - window.innerHeight;
    const ratio = scrollable <= 0 ? 1 : (window.scrollY + window.innerHeight) / doc.scrollHeight;
    const reached = DEPTHS.filter((d) => ratio * 100 >= d - 1).pop() || 0;
    if (reached > this.depth) this.depth = reached;
  }

  // --- CTA visibility ---------------------------------------------------

  observeCta() {
    const ctas = document.querySelectorAll(".specialty-cta");
    this.ctaPresent = ctas.length > 0;
    this.ctaSeen = false;
    if (!this.ctaPresent || !("IntersectionObserver" in window)) return;
    this.ctaObserver = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) {
        this.ctaSeen = true;
        this.ctaObserver.disconnect();
      }
    }, { threshold: 0.5 });
    ctas.forEach((el) => this.ctaObserver.observe(el));
  }

  // --- price-list sections ----------------------------------------------

  observeSections() {
    const sections = document.querySelectorAll(".modern-medical-services-page section.specialty-section");
    if (sections.length === 0 || !("IntersectionObserver" in window)) return;
    this.sectionObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        const name = entry.target.querySelector("h2")?.textContent.trim();
        if (!name || this.seenSections.has(name)) return;
        this.seenSections.add(name);
        this.track("$section_view", { page: this.page, section: name });
      });
    }, { threshold: 0.3 });
    sections.forEach((el) => this.sectionObserver.observe(el));
  }

  // --- booking iframe bridge -------------------------------------------

  bookingMessage(event) {
    if (!BOOKING_ORIGINS.includes(event.origin)) return;
    const data = typeof event.data === "string" ? { type: "spinalcare:booking", step: event.data.replace(/^booking:/, "") } : event.data;
    if (!data || data.type !== "spinalcare:booking" || !data.step) return;
    this.track("$booking", {
      step: String(data.step).slice(0, 30),
      page: this.page,
      service: data.service ? String(data.service).slice(0, 100) : undefined,
      doctor: data.doctor ? String(data.doctor).slice(0, 100) : undefined,
    });
  }

  // --- leave --------------------------------------------------------------

  leave() {
    if (this.sent) return;
    const seconds = this.activeSeconds();
    this.measureDepth();
    if (seconds === 0 && this.depth === 0) return;
    this.sent = true;
    this.track("$leave", {
      page: this.page,
      seconds: seconds,
      depth: this.depth,
      cta_present: this.ctaPresent,
      cta_seen: this.ctaSeen,
    });
  }

  track(name, properties) {
    if (window.ahoy && !window.location.pathname.startsWith("/dashboard")) ahoy.track(name, properties);
  }
}
