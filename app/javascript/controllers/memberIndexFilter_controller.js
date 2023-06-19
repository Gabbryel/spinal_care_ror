import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['btnTrigger', 'filterForm']
  connect() {
    // let filterByProfessionForm = document.getElementsByTagName('form')[0]
    // filterByProfessionForm.setAttribute('id', 'filter-proffesion-form')
    // filterByProfessionForm.setAttribute('data-memberIndexFilter-target', 'filterForm');
  }
}