import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    console.log('navbarFixed connecting...now')
  }
  navbarFixed() {
    window.onscroll = () => {
      let navbar = document.getElementById('navbar');
      let navbarMenu = document.getElementById('navbar-menu');
      let navbarDistToTop = navbar.getBoundingClientRect().bottom
      if (navbarDistToTop < 73 ) {
        navbarMenu.style.position = 'fixed';
        navbarMenu.style.width = '100vw';
        navbarMenu.style.top = '0';
      } else if (navbarDistToTop >= 73 ) {
        navbarMenu.style.position = 'relative';
        navbarMenu.style.width = 'max-content';
        navbarMenu.style.top = 'unset';
      }
    }
  }
}