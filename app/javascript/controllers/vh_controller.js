import { Controller } from "@hotwired/stimulus";
import { useWindowResize } from 'stimulus-use';

export default class extends Controller {
  static targets = ['height']

  connect() {
    useWindowResize(this)
    // After the first frame: reading the viewport while Turbo renders forced a
    // layout on every page.
    requestAnimationFrame(() => {
      document.documentElement.style.setProperty("--vh", `${window.innerHeight * 0.01}px`);
    });
  }
  windowResize({ width, height, event }) {
    document.documentElement.style.setProperty("--vh", `${height * 0.01}px`);
  }
}