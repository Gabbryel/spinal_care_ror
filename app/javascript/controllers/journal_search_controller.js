import { Controller } from "@hotwired/stimulus";

// Live search over the activity journal (admin/audit): filters the selected
// user's actions and page views as you type, hides days left empty, and
// shows a match count. Diacritics are ignored ("sters" matches "șters").
// Connects to data-controller="journal-search"
export default class extends Controller {
  static targets = ["input", "count", "empty", "day", "entry", "view", "views", "clear"];

  connect() {
    this.filter();
  }

  filter() {
    const term = this.normalize(this.inputTarget.value);
    let matches = 0;

    this.entryTargets.forEach((entry) => {
      const hit = term === "" || this.textOf(entry).includes(term);
      entry.hidden = !hit;
      if (hit) matches++;
    });

    this.viewTargets.forEach((view) => {
      const hit = term === "" || this.textOf(view).includes(term);
      view.hidden = !hit;
      if (hit) matches++;
    });

    // A day's "a vizualizat N pagini" block: open it while searching so the
    // matching pages are visible, hide it when none of its pages match.
    this.viewsTargets.forEach((block) => {
      const visible = block.querySelectorAll("li:not([hidden])").length;
      block.hidden = visible === 0;
      block.open = term !== "" && visible > 0;
    });

    this.dayTargets.forEach((day) => {
      const visible = day.querySelectorAll("[data-journal-search-target='entry']:not([hidden]), [data-journal-search-target='view']:not([hidden])").length;
      day.hidden = visible === 0;
    });

    if (this.hasCountTarget) {
      this.countTarget.textContent = term === "" ? "" : `${matches} ${matches === 1 ? "rezultat" : "rezultate"}`;
    }
    if (this.hasEmptyTarget) this.emptyTarget.hidden = !(term !== "" && matches === 0);
    if (this.hasClearTarget) this.clearTarget.hidden = term === "";
  }

  clear() {
    this.inputTarget.value = "";
    this.filter();
    this.inputTarget.focus();
  }

  // Escape clears the search without leaving the field.
  keydown(event) {
    if (event.key === "Escape" && this.inputTarget.value !== "") {
      event.preventDefault();
      this.clear();
    }
  }

  textOf(element) {
    if (!element.dataset.searchText) {
      element.dataset.searchText = this.normalize(element.textContent);
    }
    return element.dataset.searchText;
  }

  normalize(text) {
    return text
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .replace(/\s+/g, " ")
      .trim();
  }
}
