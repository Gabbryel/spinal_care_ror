import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="table-filter"
export default class extends Controller {
  static targets = [
    "searchInput",
    "row",
    "clearButton",
    "emptyState",
    "table",
    "tbody",
  ];

  connect() {
    this.filterTable();
  }

  filterTable() {
    const searchTerm = this.searchInputTarget.value.toLowerCase().trim();
    let visibleCount = 0;

    this.rowTargets.forEach((row) => {
      const source = row.dataset.source || "";
      const city = row.dataset.city || "";
      const country = row.dataset.country || "";

      const matches =
        source.includes(searchTerm) ||
        city.includes(searchTerm) ||
        country.includes(searchTerm);

      if (matches) {
        row.style.display = "";
        visibleCount++;
      } else {
        row.style.display = "none";
      }
    });

    // Show/hide clear button
    if (searchTerm.length > 0) {
      this.clearButtonTarget.style.display = "block";
    } else {
      this.clearButtonTarget.style.display = "none";
    }

    // Show/hide empty state
    if (visibleCount === 0) {
      this.tableTarget.style.display = "none";
      this.emptyStateTarget.style.display = "block";
    } else {
      this.tableTarget.style.display = "table";
      this.emptyStateTarget.style.display = "none";
    }
  }

  clearFilter() {
    this.searchInputTarget.value = "";
    this.filterTable();
    this.searchInputTarget.focus();
  }
}
