import { Controller } from "@hotwired/stimulus";
import { useWindowResize } from 'stimulus-use';

export default class extends Controller {
  static targets = ['height']

  connect() {
    useWindowResize(this)
    document.documentElement.style.setProperty("--vh", `${window.innerHeight * 0.01}px`);
  }
  windowResize({ width, height, event }) {
    document.documentElement.style.setProperty("--vh", `${height * 0.01}px`);
  }
}