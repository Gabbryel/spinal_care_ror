import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["card", "professionSection", "founderSection", "nameInput"];

  connect() {
    this.currentProfession = "all";
    this.currentSpecialty = "all";
    this.currentNameFilter = "";
  }

  filterByName(event) {
    this.currentNameFilter = event.target.value.toLowerCase().trim();
    this.applyFilters();
  }

  filterByProfession(event) {
    const button = event.currentTarget;
    const profession = button.dataset.filter;

    // Update active state
    this.element
      .querySelectorAll(".filter-btn")
      .forEach((btn) => btn.classList.remove("active"));
    button.classList.add("active");

    this.currentProfession = profession;
    this.applyFilters();
  }

  filterBySpecialty(event) {
    this.currentSpecialty = event.target.value;
    this.applyFilters();
  }

  applyFilters() {
    const cards = this.cardTargets;
    const sections = this.professionSectionTargets;

    // First, show/hide cards based on all filters
    cards.forEach((card) => {
      const cardName = card.dataset.memberName || "";
      const cardProfession = card.dataset.profession || "";
      const cardSpecialty = card.dataset.specialty || "none";

      const matchesName =
        !this.currentNameFilter || cardName.includes(this.currentNameFilter);
      const matchesProfession =
        this.currentProfession === "all" ||
        cardProfession === this.currentProfession;
      const matchesSpecialty =
        this.currentSpecialty === "all" ||
        cardSpecialty === this.currentSpecialty;

      if (matchesName && matchesProfession && matchesSpecialty) {
        card.style.display = "";
      } else {
        card.style.display = "none";
      }
    });

    // Then, show/hide sections based on whether they have visible cards
    sections.forEach((section) => {
      const sectionCards = section.querySelectorAll(
        '[data-memberindexfilter-target="card"]'
      );
      const hasVisibleCards = Array.from(sectionCards).some(
        (card) => card.style.display !== "none"
      );

      if (hasVisibleCards) {
        section.style.display = "";
      } else {
        section.style.display = "none";
      }
    });

    // Handle founder section separately
    if (this.hasFounderSectionTarget) {
      const founderCard = this.founderSectionTarget.querySelector(
        '[data-memberindexfilter-target="card"]'
      );
      if (founderCard && founderCard.style.display !== "none") {
        this.founderSectionTarget.style.display = "";
      } else {
        this.founderSectionTarget.style.display = "none";
      }
    }
  }
}
