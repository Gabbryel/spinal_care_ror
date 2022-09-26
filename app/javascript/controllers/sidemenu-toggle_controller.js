import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["toggle", "hamburger", "shortline", "longline", "longline2"]
  toggle() {
      this.toggleTargets.forEach(el => {
        el.classList.add('trigger');
        el.classList.toggle('active');
      });
      let hamburger = this.hamburgerTargets[0];
      let longLine = this.longlineTargets[0];
      let longLine2 = this.longline2Targets[0];
      let shortLines = this.shortlineTargets;
      let elements = [hamburger, longLine, longLine2, shortLines].flat();

      hamburger.classList.toggle("closed");
  if (hamburger.classList.contains("closed")) {
    elements.forEach((el) => el.classList.add("trigger"));
    setTimeout(() => {
      hamburger.classList.add("active");
    }, 10);
    setTimeout(() => {
      shortLines.forEach((el) => {
        el.classList.add("active");
      });
    }, 40);
    setTimeout(() => {
      shortLines.forEach((el) => {
        el.classList.add("hidden");
      });
    }, 640);
    setTimeout(() => {
      longLine.classList.add("active-long-line-1");
    }, 670);
    setTimeout(() => {
      longLine2.classList.add("active-long-line-2");
    }, 690);
  } else if (!hamburger.classList.contains("closed")) {
    setTimeout(() => {
      longLine2.classList.remove("active-long-line-2");
    }, 10);
    setTimeout(() => {
      longLine.classList.remove("active-long-line-1");
    }, 30);
    setTimeout(() => {
      shortLines.forEach((el) => {
        el.classList.remove("hidden");
      });
    }, 640);
    setTimeout(() => {
      shortLines.forEach((el) => {
        el.classList.remove("active");
      });
    }, 740);
    setTimeout(() => {
      hamburger.classList.remove("active");
    }, 780);
  }
    }
  close() {
    this.toggleTargets.forEach(el => {
      el.classList.remove('active')
      if (el.classList.contains('fa-times')) {
        el.classList.remove('fa-times')
        el.classList.add('fa-bars')
      }
    });
  }
  toggleHamburger() {

  }
}