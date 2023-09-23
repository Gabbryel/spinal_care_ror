// controls the contact modal in homepage
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['contactModal']
  constructor(context) {
    super(context)
    this.contactModal = this.contactModalTarget
  }
  contact() {
    this.contactModal.style.display = 'block';
  }

  closeContact() {
    this.contactModal.style.display = 'none';
  }
}
