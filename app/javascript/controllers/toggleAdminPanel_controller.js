import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    let body = document.getElementsByTagName("body")[0];
    let sideMenu = document.getElementById("side-menu-options");
    let exitLink = document.getElementById("exitLink");
    body.addEventListener("keydown", (e) => {
      if (e.key === "a") {
        body.addEventListener("keydown", (e) => {
          if (e.key === "d") {
            body.addEventListener("keydown", (e) => {
              if (e.key === "m" && !document.getElementById("adminLink")) {
                let adminLinkContainer = document.createElement("li");
                let adminLink = document.createElement("a");
                adminLink.setAttribute("href", "/dashboard");
                adminLink.setAttribute("id", "adminLink");
                adminLink.innerText = "Admin";
                sideMenu.insertBefore(adminLinkContainer, exitLink);
                adminLinkContainer.appendChild(adminLink);
              }
            });
          }
        });
      }
    });
  }
}

// create a function for admin link to be created on spot
// <a id="adminLink" href="/dashboard">Admin</a>
