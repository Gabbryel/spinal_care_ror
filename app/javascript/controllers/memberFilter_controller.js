import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["card"];

  filterByName(event) {
    const searchTerm = event.target.value.toLowerCase().trim();

    this.cardTargets.forEach((card) => {
      const memberName = card.dataset.memberName;

      if (searchTerm === "" || memberName.includes(searchTerm)) {
        card.style.display = "";
      } else {
        card.style.display = "none";
      }
    });

    // Hide profession sections that have no visible members
    this.updateProfessionSections();
  }

  updateProfessionSections() {
    const professionSections = document.querySelectorAll(
      ".personal-profession-section"
    );

    professionSections.forEach((section) => {
      const visibleMembers = section.querySelectorAll(
        '.modern-member-card:not([style*="display: none"])'
      );

      if (visibleMembers.length === 0) {
        section.style.display = "none";
      } else {
        section.style.display = "";
      }
    });
  }
}
