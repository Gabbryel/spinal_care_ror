import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  createAdminLink() {
    let adminLinkContainer = document.createElement("li");
    let adminLink = document.createElement("a");
    adminLink.setAttribute("href", "/dashboard");
    adminLink.setAttribute("id", "adminLink");
    adminLink.innerText = "Admin";
    adminLinkContainer.appendChild(adminLink);
    return adminLinkContainer;
  }

  showAdminLink() {
    if (window.innerWidth < 1024) {
      let sideMenu = document.getElementById("side-menu-options");
      let exitLink = document.getElementById("exitLink");
      sideMenu.insertBefore(this.createAdminLink(), exitLink);
    } else if (screen.width >= 1024) {
      let navbarMenu = document.getElementById("navbar-items");
      let navbarExitLink = document.getElementById("nav-bar-exit-link");
      let div = document.createElement("div");
      let createAdminLink = this.createAdminLink();
      createAdminLink.setAttribute("class", "active-menu-item");
      createAdminLink.append(div);
      navbarMenu.insertBefore(createAdminLink, navbarExitLink);
    }
  }
  connect() {
    let body = document.getElementsByTagName("body")[0];
    body.addEventListener("keydown", (e) => {
      if (e.key === "a") {
        body.addEventListener("keydown", (e) => {
          if (e.key === "d") {
            body.addEventListener("keydown", (e) => {
              if (e.key === "m" && !document.getElementById("adminLink")) {
                this.showAdminLink();
              }
            });
          }
        });
      }
    });
  }
}
