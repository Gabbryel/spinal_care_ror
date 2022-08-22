import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["toggle"]
  toggle() {
      this.toggleTargets.forEach(el => {
        el.classList.add('trigger');
        el.classList.toggle('active');
      });
    }
  close() {
    this.toggleTargets.forEach(el => {
      el.classList.remove('active')
    });
  }
  }