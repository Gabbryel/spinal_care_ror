import { Controller } from "@hotwired/stimulus";

// Global search box on the activity journal: submits the GET form (into the
// "audit-results" Turbo frame) 350 ms after the last keystroke, or on Enter;
// Escape clears the field and reloads the frame without a query.
// Connects to data-controller="global-search"
export default class extends Controller {
  static targets = ["input"];

  disconnect() {
    clearTimeout(this.timer);
  }

  search() {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.submit(), 350);
  }

  keydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      clearTimeout(this.timer);
      this.submit();
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.inputTarget.value = "";
      clearTimeout(this.timer);
      this.submit();
    }
  }

  submit() {
    if (this.lastSubmitted === this.inputTarget.value) return;
    this.lastSubmitted = this.inputTarget.value;
    this.element.requestSubmit();
  }
}
