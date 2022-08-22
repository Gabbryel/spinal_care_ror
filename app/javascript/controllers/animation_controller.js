import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  svgload() {
    this.element.classList.add('active-svg')
    this.element.classList.remove('inactive')
  }
  svgscroll() {
    if (window.innerHeight < this.element.getBoundingClientRect().top) {
      this.element.classList.remove('active-svg')
      this.element.classList.add('inactive')
    } else if (window.innerHeight > this.element.getBoundingClientRect().top && this.element.getBoundingClientRect().bottom > 0) {
      this.element.classList.add('trigger')
      this.element.classList.add('active-svg')
      this.element.classList.remove('inactive')
    } else if (this.element.getBoundingClientRect().bottom < 0) {
      this.element.classList.remove('active-svg')
      this.element.classList.add('inactive')
    }
  }
  }