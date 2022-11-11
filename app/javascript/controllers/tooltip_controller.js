import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['trigger', 'description']
  constructor(context) {
    super(context)
    this.triggers = this.triggerTargets
    this.descriptions = this.descriptionTargets
  }
  
  connect() {
    this.triggers.forEach((el, index) => {
      el.addEventListener('mouseover', () => {
        this.descriptions[index].style.display = 'block'
      })
      el.addEventListener('mouseleave', () => {
        this.descriptions[index].style.display = 'none'
      })
    })
  }
}