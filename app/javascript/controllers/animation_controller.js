import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["element"];

  connect() {
    this.fadeInElements();
  }

  svgload() {
    this.element.classList.add("active-svg");
    this.element.classList.remove("inactive");
  }

  svgscroll() {
    if (window.innerHeight < this.element.getBoundingClientRect().top) {
      this.element.classList.remove("active-svg");
      this.element.classList.add("inactive");
    } else if (
      window.innerHeight > this.element.getBoundingClientRect().top &&
      this.element.getBoundingClientRect().bottom > 0
    ) {
      this.element.classList.add("trigger");
      this.element.classList.add("active-svg");
      this.element.classList.remove("inactive");
    } else if (this.element.getBoundingClientRect().bottom < 0) {
      this.element.classList.remove("active-svg");
      this.element.classList.add("inactive");
    }
  }

  fadeInElements() {
    if (!this.hasElementTarget) return;

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("fade-in");
            observer.unobserve(entry.target);
          }
        });
      },
      {
        threshold: 0.1,
        rootMargin: "0px 0px -50px 0px",
      },
    );

    this.elementTargets.forEach((element) => {
      observer.observe(element);
    });
  }
}
