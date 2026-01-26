import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startDate", "endDate", "applyButton"]

  connect() {
    this.validateDates()
  }

  validateDates() {
    if (!this.hasStartDateTarget || !this.hasEndDateTarget) return

    const start = this.startDateTarget.value
    const end = this.endDateTarget.value

    if (start && end) {
      const isValid = this.isValidDateRange(start, end)
      this.toggleApplyButton(isValid)
      
      if (isValid) {
        this.clearError()
      }
    }
  }

  isValidDateRange(start, end) {
    return new Date(start) <= new Date(end)
  }

  toggleApplyButton(isValid) {
    if (this.hasApplyButtonTarget) {
      this.applyButtonTarget.disabled = !isValid
      this.applyButtonTarget.classList.toggle('disabled', !isValid)
    }
  }

  handleApply(event) {
    const start = this.startDateTarget.value
    const end = this.endDateTarget.value

    if (!start || !end) {
      event.preventDefault()
      this.showError('Vă rugăm să selectați ambele date (început și sfârșit).')
      return
    }

    if (!this.isValidDateRange(start, end)) {
      event.preventDefault()
      this.showError('Data de început trebuie să fie înainte de data de sfârșit.')
      return
    }
  }

  showError(message) {
    // Remove existing error
    this.clearError()

    const error = document.createElement('div')
    error.className = 'date-filter-error'
    error.textContent = message
    error.setAttribute('role', 'alert')
    
    if (this.hasApplyButtonTarget) {
      this.applyButtonTarget.parentElement.appendChild(error)
    }
  }

  clearError() {
    const existingError = this.element.querySelector('.date-filter-error')
    if (existingError) {
      existingError.remove()
    }
  }
}
