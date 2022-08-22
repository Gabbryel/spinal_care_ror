import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  svgload() {
    this.element.classList.add('active-svg')
  }
  svgscroll() {
    if (window.innerHeight < this.element.getBoundingClientRect().top) {
      this.element.classList.remove('active-svg')
    } else if (window.innerHeight > this.element.getBoundingClientRect().top && this.element.getBoundingClientRect().bottom > 0) {
      this.element.classList.add('active-svg')
    } else if (this.element.getBoundingClientRect().bottom < 0) {
      this.element.classList.remove('active-svg')
    }
  }
  }