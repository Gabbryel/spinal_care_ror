import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    // Wait for images and content to load
    if (document.readyState === "complete") {
      this.matchHeights();
    } else {
      window.addEventListener("load", () => this.matchHeights());
    }

    this.resizeHandler = this.matchHeights.bind(this);
    window.addEventListener("resize", this.resizeHandler);
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler);
  }

  matchHeights() {
    requestAnimationFrame(() => {
      if (window.innerWidth >= 992) {
        const cardSection = document.querySelector(".member-card-section");
        const bioSection = document.querySelector(".member-bio-section");

        if (cardSection && bioSection) {
          const cardHeight = cardSection.offsetHeight;
          bioSection.style.height = `${cardHeight}px`;
          console.log(
            "Card height:",
            cardHeight,
            "Bio height set to:",
            cardHeight
          );
        }
      } else {
        const bioSection = document.querySelector(".member-bio-section");
        if (bioSection) {
          bioSection.style.height = "auto";
        }
      }
    });
  }
}
