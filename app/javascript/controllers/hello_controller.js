import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    window.onscroll = () => {
      console.log(this.element.getBoundingClientRect().top, window.innerHeight)
    }
  }
}
