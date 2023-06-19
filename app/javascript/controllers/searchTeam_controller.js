import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.value = "";
  }
  cssController(counter, mainContainer, members) {
    const validAnswer = () => {
      let noAnswer = document.getElementById('medical-team__no-answer');
      if (noAnswer) {
        mainContainer.removeChild(noAnswer)
      }
    }
    if (counter === 0 ) {
      if (!document.getElementById('medical-team__no-answer')) {
        let answer = document.createElement('div');
        answer.setAttribute('id', 'medical-team__no-answer')
        let image = "<img src= 'https://res.cloudinary.com/www-spinalcare-ro/image/upload/v1665771386/development/SPINAL_CARE_LOGO_ICON_CC_wulwbr.svg' >"
        answer.innerHTML = image;
        mainContainer.appendChild(answer);
        let answerTxt =  document.createElement('p');
        answerTxt.innerText = 'Niciun rezultat pentru căutarea dvs.!'
        answer.appendChild(answerTxt);
      }


      mainContainer.style.gridTemplateColumns = '1fr';
      members.forEach(m => m.style.justifySelf = 'center')
    } else if (counter === 1) {
      mainContainer.style.gridTemplateColumns = '1fr';
      members.forEach(m => m.style.justifySelf = 'center');
      validAnswer()
    } else if (counter === 2) {
      mainContainer.style.gridTemplateColumns = 'repeat(2, minmax(300px, 1fr))';
      members.forEach(m => m.style.justifySelf = 'center');
      validAnswer()
    } else if (counter === 3) {
      mainContainer.style.gridTemplateColumns = 'repeat(3, minmax(300px, 1fr))';
      members.forEach(m => m.style.justifySelf = 'center');
      validAnswer()
    } else {
      mainContainer.style.gridTemplateColumns = 'repeat(auto-fill, minmax(300px, 1fr))';
      members.forEach(m => m.style.justifySelf = 'unset');
      validAnswer()
    }
  }
  filter() {
    let reference = this.element.parentElement.innerText || '';
    let members = Array.from(document.getElementsByClassName('member-card'));
    let mainContainer = document.getElementById('medical-team');
    let counter = 0;
    members.forEach( m => {
      (m.dataset.profession === reference ||
       m.dataset.specialty === reference ||
       reference === 'Toată echipa') ? (m.style.display = 'block', counter++) : (m.style.display = 'none');
    })
    this.cssController(counter, mainContainer, members)
  }
  search() {
    let nameReference = this.element.value.toLowerCase();
    let members = Array.from(document.getElementsByClassName('member-card'));
    let mainContainer = document.getElementById('medical-team');
    let counter = 0;
    members.forEach(m => {
      if (m.dataset.identity.toLowerCase().includes(nameReference)) {
        m.style.display = 'block'
        counter++
      } else {
        m.style.display = 'none'
      }
    })
    this.cssController(counter, mainContainer, members)
  }
  
  activateForm() {
    let elementValue = this.element.innerText;
    let professionForm = document.getElementById('filter-proffesion-form');
    let specialtyForm = document.getElementById('filter-specialty-form');
    let nameForm = document.getElementById('filter-name-form');
    if (elementValue === 'Profesie') {
      professionForm.style.display = 'block';
      specialtyForm.style.display = 'none';
      nameForm.style.display = 'none';
    } else if (elementValue === 'Specialitate') {
      specialtyForm.style.display = 'block';
      professionForm.style.display = 'none';
      nameForm.style.display = 'none';
    } else if (elementValue === 'Nume') {
      specialtyForm.style.display = 'none';
      professionForm.style.display = 'none';
      nameForm.style.display = 'block';
    }
  }
  searchName(event) {
    if (event.key === 'Enter') {
      setTimeout(() => {
        let query = window.location.search;
        const urlParams  = new URLSearchParams(query);
        const nameReference = urlParams.get('search[name]')
        let members = Array.from(document.getElementsByClassName('member-card'));
        let mainContainer = document.getElementById('medical-team');
        let counter = 0;
        members.forEach(m => {
          if (m.dataset.identity.toLowerCase().includes(nameReference)) {
            m.style.display = 'block'
            counter++
          } else {
            m.style.display = 'none'
          }
        })
        this.cssController(counter, mainContainer, members)
      }, 500 )
    }
  }
}