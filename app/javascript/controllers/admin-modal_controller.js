import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Make modal available globally for opening
    window.openAdminModal = (modalId) => this.open(modalId)
  }

  open(modalId) {
    const modal = typeof modalId === 'string' 
      ? document.getElementById(modalId) 
      : this.element

    if (modal) {
      modal.classList.remove('hidden')
      document.body.style.overflow = 'hidden'
      
      // Animate modal entrance
      requestAnimationFrame(() => {
        const panel = modal.querySelector('.relative')
        if (panel) {
          panel.classList.add('animate-slideIn')
        }
      })
    }
  }

  close(event) {
    // Don't close if clicking inside the modal panel
    if (event && event.target.closest('.relative:not(.fixed)')) {
      return
    }

    const modal = this.element
    const panel = modal.querySelector('.relative')
    
    if (panel) {
      panel.classList.add('animate-slideOut')
      
      setTimeout(() => {
        modal.classList.add('hidden')
        document.body.style.overflow = ''
        panel.classList.remove('animate-slideIn', 'animate-slideOut')
      }, 200)
    } else {
      modal.classList.add('hidden')
      document.body.style.overflow = ''
    }
  }

  // Open modal from button click
  openModal(event) {
    event.preventDefault()
    const modalId = event.currentTarget.dataset.modalId
    if (modalId) {
      this.open(modalId)
    }
  }
}
