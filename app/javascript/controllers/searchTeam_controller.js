import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element.value = "";
  }

  filter() {
    let professionDivs = document.getElementsByClassName("profession-div");
    this.setProfessionDivsDisplayToGrid(professionDivs);
    let reference = this.element.parentElement.innerText || "";
    let members = Array.from(
      document.getElementsByClassName("modern-member-card")
    );
    let counter = 0;
    members.forEach((m) => {
      m.dataset.profession === reference ||
      m.dataset.specialty === reference ||
      reference === "Toată echipa"
        ? ((m.style.display = "block"), counter++)
        : (m.style.display = "none");
    });
    if (reference == "Toată echipa") {
      return;
    } else {
      this.setProfessionDivsDisplayToNone(professionDivs);
      setTimeout(() => {
        let mainContainer = document.getElementById("medical-team");
        this.cssController(counter, mainContainer, members);
      }, 10);
    }
  }

  // search() {
  //   let professionDivs = document.getElementsByClassName('profession-div');
  //   this.setProfessionDivsDisplayToGrid(professionDivs)
  //   let nameReference = this.element.value.toLowerCase();
  //   let members = Array.from(document.getElementsByClassName('modern-member-card'));
  //   let counter = 0;
  //   members.forEach(m => {
  //     if (m.dataset.identity.toLowerCase().includes(nameReference)) {
  //       m.style.display = 'block'
  //       counter++
  //     } else {
  //       m.style.display = 'none'
  //       m.style.height = '0'
  //     }
  //   })
  //   this.setProfessionDivsDisplayToNone(professionDivs)
  //   setTimeout(() => {
  //     let mainContainer = document.getElementById('medical-team');
  //     this.cssController(counter, mainContainer, members)
  //   }, 100)
  // }

  activateForm() {
    let elementValue = this.element.innerText;
    let professionForm = document.getElementById("filter-proffesion-form");
    let specialtyForm = document.getElementById("filter-specialty-form");
    // let nameForm = document.getElementById('filter-name-form');
    if (elementValue === "Profesie") {
      professionForm.style.display = "block";
      specialtyForm.style.display = "none";
      // nameForm.style.display = 'none';
    } else if (elementValue === "Specialitate") {
      specialtyForm.style.display = "block";
      professionForm.style.display = "none";
      // nameForm.style.display = 'none';
    } else if (elementValue === "Nume") {
      specialtyForm.style.display = "none";
      professionForm.style.display = "none";
      // nameForm.style.display = 'block';
    }
  }
  // searchName(event) {
  //   if (event.key === 'Enter') {
  //     setTimeout(() => {
  //       let query = window.location.search;
  //       const urlParams  = new URLSearchParams(query);
  //       const nameReference = urlParams.get('search[name]')
  //       let members = Array.from(document.getElementsByClassName('modern-member-card'));
  //       let mainContainer = document.getElementById('medical-team');
  //       let counter = 0;
  //       members.forEach(m => {
  //         if (m.dataset.identity.toLowerCase().includes(nameReference)) {
  //           m.style.display = 'block'
  //           counter++
  //         } else {
  //           m.style.display = 'none'
  //         }
  //       })
  //       this.cssController(counter, mainContainer, members)
  //     }, 500 )
  //   }
  // }

  setProfessionDivsDisplayToNone(professionDivs) {
    Array.from(professionDivs).forEach((pd) => {
      let count = 0;
      Array.from(pd.children).forEach((chd) => {
        if (chd.style.display !== "none") {
          count++;
        }
        return;
      });
      if (count === 0) {
        pd.style.display = "none";
        pd.removeAttribute("id", "profession-div__custom");
      } else if (count > 0 && count < 4) {
        console.log(count);
        pd.classList.add(`grid`);
        pd.classList.add(`!grid-cols-[repeat(${count},minmax(350px,_1fr))]`);
        // pd.style.gridTemplateColumns = `repeat(auto-fill, minmax(300px, 1fr))`
      } else {
        pd.classList.add(`!grid-cols-[auto-fill,minmax(350px,_1fr))]`);
      }
    });
  }

  setProfessionDivsDisplayToGrid(professionDivs) {
    Array.from(professionDivs).forEach((pd) => {
      pd.style.display = "grid";
      if (pd.children.length < 4) {
        pd.style.gridTemplateColumns = `repeat(${pd.children.length}, minmax(300px, 1fr))`;
      } else {
        pd.style.gridTemplateColumns = `repeat(auto-fill, minmax(300px, 1fr))`;
      }
      pd.style.maxWidth = "unset";
      pd.style.justifySelf = "unset";
      Array.from(pd.children).forEach((chd) => {
        chd.style.display = "unset";
        chd.style.maxWidth = "350px";
      });
    });
  }

  cssController(counter, mainContainer, members) {
    const validAnswer = () => {
      let noAnswer = document.getElementById("medical-team__no-answer");
      if (noAnswer) {
        mainContainer.removeChild(noAnswer);
      }
    };
    if (counter === 0) {
      if (!document.getElementById("medical-team__no-answer")) {
        let answer = document.createElement("div");
        answer.setAttribute("id", "medical-team__no-answer");
        // let image = "<img src= 'https://res.cloudinary.com/www-spinalcare-ro/image/upload/v1665771386/development/SPINAL_CARE_LOGO_ICON_CC_wulwbr.svg' >"
        // answer.innerHTML = image;
        mainContainer.appendChild(answer);
        let answerTxt = document.createElement("p");
        answerTxt.innerText = "Niciun rezultat pentru căutarea dvs.!";
        answer.appendChild(answerTxt);
      }
      validAnswer();
    }
  }
}
