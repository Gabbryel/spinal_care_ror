import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  svgload() {
    this.element.classList.add('active-svg')
  }
  svgscroll() {
    let windowHeight = window.innerHeight;
        let distanceFromTop = this.element.getBoundingClientRect().bottom;
        if (distanceFromTop > windowHeight * (-0.1)) {
          this.element.classList.add('active-svg')
        } else if (distanceFromTop < windowHeight * (0.1)) {
          this.element.classList.remove('active-svg')
    }}
  }