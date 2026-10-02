import { Controller } from "@hotwired/stimulus"

// The questionnaire one section at a time. Without JavaScript every section
// shows and the browser's own `required` check applies; with it, each step is
// checked before moving on (hidden required fields would otherwise block the
// submit without telling anyone why).
export default class extends Controller {
  static targets = ["step", "progress", "back", "next", "submit", "error"]

  connect() {
    if (this.stepTargets.length < 2) return
    this.element.noValidate = true
    this.index = this.firstStepWithError()
    this.progressTarget.hidden = false
    this.render()
  }

  next() {
    if (!this.validate(this.stepTargets[this.index])) return
    this.index = Math.min(this.index + 1, this.stepTargets.length - 1)
    this.render(true)
  }

  back() {
    this.index = Math.max(this.index - 1, 0)
    this.render(true)
  }

  // Native submit: check every step, jump to the first one missing an answer.
  submit(event) {
    if (this.stepTargets.length < 2) return
    const invalid = this.stepTargets.findIndex((step) => !this.validate(step, false))
    if (invalid === -1) return
    event.preventDefault()
    this.index = invalid
    this.render(true)
    this.validate(this.stepTargets[invalid])
  }

  render(scroll = false) {
    const last = this.stepTargets.length - 1
    this.stepTargets.forEach((step, i) => { step.hidden = i !== this.index })
    this.backTarget.hidden = this.index === 0
    this.nextTarget.hidden = this.index === last
    this.submitTarget.hidden = this.index !== last
    this.progressTarget.textContent = `Pasul ${this.index + 1} din ${last + 1}`
    this.errorTarget.hidden = true
    if (scroll) {
      this.element.scrollIntoView({ behavior: "smooth", block: "start" })
      this.stepTargets[this.index].querySelector("h2")?.focus({ preventScroll: true })
    }
  }

  validate(step, show = true) {
    const answered = (fieldset) => fieldset.querySelector("input:checked") || fieldset.querySelector("select")?.value
    const missing = [...step.querySelectorAll("fieldset[data-required]")].filter((fieldset) => !answered(fieldset))
    step.querySelectorAll("fieldset").forEach((f) => f.classList.toggle("is-missing", missing.includes(f)))
    if (missing.length === 0) return true
    if (show) {
      this.errorTarget.textContent = missing.length === 1
        ? "Vă rugăm să răspundeți la întrebarea marcată."
        : `Vă rugăm să răspundeți la cele ${missing.length} întrebări marcate.`
      this.errorTarget.hidden = false
      missing[0].querySelector("input, select")?.focus()
    }
    return false
  }

  // After a server-side error, open on the first step that lacks an answer.
  firstStepWithError() {
    const i = this.stepTargets.findIndex((step) => !this.validate(step, false))
    this.stepTargets.forEach((step) => step.querySelectorAll(".is-missing").forEach((f) => f.classList.remove("is-missing")))
    return i === -1 || !this.element.querySelector(".survey-error:not([hidden])") ? 0 : i
  }
}
