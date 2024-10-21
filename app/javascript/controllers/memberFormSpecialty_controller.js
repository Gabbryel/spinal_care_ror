import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["profession", "medic"]
  connect() {
    console.log('connected')
    let medProf = document.getElementById('med-prof');
    let professions = this.professionTargets;
    let medics = this.medicTargets;
    professions.forEach((p, i) => {
      let value = Array.from(p.children).find(el => el.value === p.value).innerHTML
      if (medProf.dataset.medicalProfessions.includes(value)) {
        medics[i].classList.add('trigger')
        setTimeout(() => {
          medics[i].classList.add('active')
        }, 100)
      }
    })
  }
  change() {
    let medProf = document.getElementById('med-prof');
    let medics = this.medicTargets;
    let professions = this.professionTargets;
    professions.forEach((p, i) => {
      let value = Array.from(p.children).find(el => el.value === p.value).innerHTML
      if (medProf.dataset.medicalProfessions.includes(value)) {
        medics[i].classList.add('trigger')
        setTimeout(() => {
          medics[i].classList.add('active')
        }, 100)
      }
      else {
        medics[i].classList.remove('active')
        setTimeout(() => {
          medics[i].classList.remove('trigger')
        }, 100)
      }
     }
    )
  }
}