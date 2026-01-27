import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.trackClicks();
  }

  trackClicks() {
    // Track all link clicks
    document.addEventListener("click", (event) => {
      const link = event.target.closest("a");
      if (link && !this.isAdminLink(link)) {
        this.trackClick(link, "link");
      }

      // Track button clicks (non-form buttons)
      const button = event.target.closest("button");
      if (button && button.type !== "submit" && !this.isAdminButton(button)) {
        this.trackClick(button, "button");
      }
    });
  }

  trackClick(element, type) {
    const destination =
      element.href ||
      element.dataset.href ||
      element.getAttribute("data-url") ||
      "internal-action";
    const text = element.textContent.trim().substring(0, 100); // Limit text length
    const classes = element.className;
    const id = element.id;
    const currentPage = window.location.pathname;

    // Send to Ahoy
    if (window.ahoy) {
      ahoy.track("$click", {
        element_type: type,
        destination: destination,
        text: text,
        classes: classes,
        element_id: id,
        page: currentPage,
        timestamp: new Date().toISOString(),
      });
    }
  }

  isAdminLink(link) {
    const href = link.href || "";
    return (
      href.includes("/dashboard") ||
      href.includes("/admin") ||
      href.includes("/users/sign") ||
      link.closest("[data-no-track]")
    );
  }

  isAdminButton(button) {
    return (
      button.closest("[data-no-track]") ||
      button.closest(".analytics-page-enhanced")
    );
  }
}
