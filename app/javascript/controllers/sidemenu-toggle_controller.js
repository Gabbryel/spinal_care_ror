import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["toggle"]
  toggle() {
      this.toggleTargets.forEach(el => {
        el.classList.add('trigger');
        el.classList.toggle('active');
        setTimeout(() => {
          el.classList.add('hidden')
        }, 200)
        setTimeout(() => {
          el.classList.remove('hidden')
          el.classList.add('show')
        }, 900)
        setTimeout(() => {
          el.classList.toggle('fa-bars')
          el.classList.toggle('fa-times')
        }, 1000)
      });
    }
  close() {
    this.toggleTargets.forEach(el => {
      el.classList.remove('active')
      if (el.classList.contains('fa-times')) {
        el.classList.remove('fa-times')
        el.classList.add('fa-bars')
      }
    });
  }
  }