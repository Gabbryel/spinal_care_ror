import { Controller } from "@hotwired/stimulus";

// Gives an iframe its src only when its Bootstrap modal first opens, or when
// the visitor points at a button that opens it (a head start of a few
// hundred milliseconds). Used for the booking iframe, which would otherwise
// load the whole booking application on every page.
// Connects to data-controller="lazy-iframe" on the .modal element.
export default class extends Controller {
  static targets = ["frame"];

  connect() {
    this.load = this.load.bind(this);
    this.warmUp = this.warmUp.bind(this);
    this.element.addEventListener("show.bs.modal", this.load);
    document.addEventListener("pointerover", this.warmUp, { passive: true });
    document.addEventListener("focusin", this.warmUp);
  }

  disconnect() {
    this.element.removeEventListener("show.bs.modal", this.load);
    this.stopWarmUp();
  }

  warmUp(event) {
    const opener = event.target.closest && event.target.closest(`[data-bs-target="#${this.element.id}"]`);
    if (opener) this.load();
  }

  load() {
    this.stopWarmUp();
    this.frameTargets.forEach((frame) => {
      if (!frame.getAttribute("src") && frame.dataset.src) frame.setAttribute("src", frame.dataset.src);
    });
  }

  stopWarmUp() {
    document.removeEventListener("pointerover", this.warmUp);
    document.removeEventListener("focusin", this.warmUp);
  }
}
