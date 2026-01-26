import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    interval: { type: Number, default: 1200000 }, // 20 minutes default
  };

  connect() {
    this.startAutoRefresh();
  }

  disconnect() {
    this.stopAutoRefresh();
  }

  startAutoRefresh() {
    const heroSection = this.element.querySelector(".hero-kpis");

    if (!heroSection) return;

    this.refreshTimer = setInterval(() => {
      this.refreshHeroKPIs(heroSection);
    }, this.intervalValue);
  }

  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
    }
  }

  async refreshHeroKPIs(heroSection) {
    const urlParams = new URLSearchParams(window.location.search);
    const refreshUrl = window.location.pathname + "?" + urlParams.toString();

    try {
      const response = await fetch(refreshUrl, {
        headers: {
          Accept: "text/html",
          "X-Requested-With": "XMLHttpRequest",
        },
      });

      const html = await response.text();
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, "text/html");
      const newHeroSection = doc.querySelector(".hero-kpis");

      if (newHeroSection) {
        heroSection.innerHTML = newHeroSection.innerHTML;
        this.showNotification("Date actualizate");
      }
    } catch (error) {
      console.error("Eroare la actualizarea datelor:", error);
    }
  }

  showNotification(message) {
    const notification = document.createElement("div");
    notification.className = "analytics-notification";
    notification.textContent = message;
    document.body.appendChild(notification);

    // Auto-remove after 2 seconds
    setTimeout(() => {
      notification.classList.add("fade-out");
      setTimeout(() => notification.remove(), 300);
    }, 2000);
  }
}
