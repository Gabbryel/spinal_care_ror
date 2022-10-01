import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["profession", "specialty"]
  change() {
    let specialty = this.specialtyTargets[0];
    let profession = this.professionTargets[0]
    console.log(profession.children[profession.value].innerText)
    if (profession.children[profession.value].innerText === 'medic') {
      specialty.classList.add('trigger')
      setTimeout(() => {specialty.classList.add('active')}, 100)
    } else {
      specialty.classList.remove('active')
      setTimeout(() => {specialty.classList.remove('trigger')}, 100)
    }
  }
}