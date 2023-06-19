import {Controller} from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['bio', 'trix', 'more']
  connect() {
    let setTrix = document.getElementsByClassName('trix-content')[0];
    setTrix.setAttribute('data-bio-target', 'trix');
    let bio = this.bioTargets[0];
    let trix = this.trixTargets[0];
    let more = this.moreTargets[0];

    if (trix.offsetHeight > bio.offsetHeight) {
      more.style.display = 'block'
    }
  }
}