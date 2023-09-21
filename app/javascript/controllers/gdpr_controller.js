import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['acceptBtn', 'acceptModal']

  constructor(context) {
    super(context)
    this.acceptBtn = this.acceptBtnTarget
    this.acceptModal = this.acceptModalTarget
  }
  connect() {
    if (sessionStorage.gdpr === '1') {
      this.acceptModal.style.display = "none";
    } else {
      this.acceptModal.style.display = "block";
    }
  }
  acceptGdpr() {
    this.acceptModal.style.display = "none";
    sessionStorage.setItem('gdpr', '1');
  }
}
