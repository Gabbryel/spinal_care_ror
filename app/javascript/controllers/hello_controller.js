import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    window.onscroll = () => {
      if (window.innerHeight < this.element.getBoundingClientRect().top) {
        console.log('out')
      } else if (window.innerHeight > this.element.getBoundingClientRect().top && this.element.getBoundingClientRect().bottom > 0) {
        console.log('in')
      } else if (this.element.getBoundingClientRect().bottom < 0) {
        console.log('out')
      }
    }
  }
}
