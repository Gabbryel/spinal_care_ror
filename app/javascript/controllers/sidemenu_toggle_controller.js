import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["toggle", "hamburger", "shortline", "longline", "longline2"]
  constructor(context) {
    super(context)
    this.hamburger = this.hamburgerTarget
    this.longLine = this.longlineTarget
    this.longLine2 = this.longline2Target
    this.shortLines = this.shortlineTargets
    this.elements = [this.hamburger, this.longLine, this.longLine2, this.shortLines].flat()
  }

  toggle() {
      this.toggleTargets.forEach(el => {
        el.classList.add('trigger');
        el.classList.toggle('active');
      });
      this.hamburger.classList.toggle("closed");
      if (document.getElementById('navbar-toggle')) {
        var navbar = document.getElementById('navbar-toggle');
      } else if (document.getElementById('admin-navbar-toggle')) {
        var adminNavbar = document.getElementById('admin-navbar-toggle');
      }
      if (navbar) {
        navbar.style.zIndex = 'unset';
      } else if (adminNavbar) {
        adminNavbar.style.zIndex = '1';
      }
  if (this.hamburger.classList.contains("closed")) {
    this.elements.forEach((el) => el.classList.add("trigger"));
    setTimeout(() => {
      this.hamburger.classList.add("active");
    }, 10);
    setTimeout(() => {
      this.shortLines.forEach((el) => {
        el.classList.add("active");
      });
    }, 40);
    setTimeout(() => {
      this.shortLines.forEach((el) => {
        el.classList.add("hidden");
      });
    }, 640);
    setTimeout(() => {
      this.longLine.classList.add("active-long-line-1");
    }, 670);
    setTimeout(() => {
      this.longLine2.classList.add("active-long-line-2");
    }, 690);
  } else if (!this.hamburger.classList.contains("closed")) {
    if (navbar) {
      navbar.style.zIndex = '1002';
    } else if (adminNavbar) {
      adminNavbar.style.zIndex = '1002';
    }
    setTimeout(() => {
      this.longLine2.classList.remove("active-long-line-2");
    }, 10);
    setTimeout(() => {
      this.longLine.classList.remove("active-long-line-1");
    }, 30);
    setTimeout(() => {
      this.shortLines.forEach((el) => {
        el.classList.remove("hidden");
      });
    }, 640);
    setTimeout(() => {
      this.shortLines.forEach((el) => {
        el.classList.remove("active");
      });
    }, 740);
    setTimeout(() => {
      this.hamburger.classList.remove("active");
    }, 780);
  }}

  close() {
    this.hamburger.classList.remove("closed");
    this.toggleTargets.forEach(el => {
      el.classList.remove('active')
    });
    if (navbar) {
      navbar.style.zIndex = '1002';
    } else if (adminNavbar) {
      adminNavbar.style.zIndex = '1002';
    }

    setTimeout(() => {
      this.longLine2.classList.remove("active-long-line-2");
    }, 10);
    setTimeout(() => {
      this.longLine.classList.remove("active-long-line-1");
    }, 30);
    setTimeout(() => {
      this.shortLines.forEach((el) => {
        el.classList.remove("hidden");
      });
    }, 640);
    setTimeout(() => {
      this.shortLines.forEach((el) => {
        el.classList.remove("active");
      });
    }, 740);
    setTimeout(() => {
      this.hamburger.classList.remove("active");
    }, 780);
  }
}