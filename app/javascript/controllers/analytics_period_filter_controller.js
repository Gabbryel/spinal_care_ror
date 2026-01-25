import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["form", "periodSelect", "customDates"];

  connect() {
    console.log("Analytics period filter controller connected");
  }

  toggleCustomDates() {
    const period = this.periodSelectTarget.value;

    if (period === "custom") {
      this.customDatesTarget.classList.remove("hidden");
    } else {
      this.customDatesTarget.classList.add("hidden");
      // Auto-submit for preset periods
      this.formTarget.submit();
    }
  }

  handlePeriodChange(event) {
    // Prevent auto-submit when selecting custom to allow date input
    if (this.periodSelectTarget.value !== "custom") {
      // Small delay to ensure the select value is updated
      setTimeout(() => {
        this.formTarget.submit();
      }, 100);
    }
  }
}
