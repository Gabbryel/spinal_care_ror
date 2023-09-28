import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["profession", "specialty", "grade"]
  connect() {
    let medProf = document.getElementById('med-prof');
    let specialties = this.specialtyTargets;
    let professions = this.professionTargets;
    let grades = this.gradeTargets;
    professions.forEach((p, i) => {
      let value = Array.from(p.children).find(el => el.value === p.value).innerHTML
      if (medProf.dataset.medicalProfessions.includes(value)) {
        specialties[i].classList.add('trigger')
        grades[i].classList.add('trigger')
        setTimeout(() => {
          specialties[i].classList.add('active')
          grades[i].classList.add('active')
        }, 100)
      }
    })
  }
  change() {
    let medProf = document.getElementById('med-prof');
    let specialties = this.specialtyTargets;
    let professions = this.professionTargets;
    let grades = this.gradeTargets;
    professions.forEach((p, i) => {
      let value = Array.from(p.children).find(el => el.value === p.value).innerHTML
      if (medProf.dataset.medicalProfessions.includes(value)) {
        specialties[i].classList.add('trigger')
        grades[i].classList.add('trigger')
        setTimeout(() => {
          specialties[i].classList.add('active')
          grades[i].classList.add('active')
        }, 100)
      }
      else {
        specialties[i].classList.remove('active')
        grades[i].classList.remove('active')
        setTimeout(() => {
          specialties[i].classList.remove('trigger')
          grades[i].classList.remove('trigger')
        }, 100)
      }
     }
    )
  }
}