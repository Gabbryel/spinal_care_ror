import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const reviews = Array.from(this.element.children);
    let reviewsInterval =
      setInterval(() => {
        reviews.forEach((el) => el.classList.remove('inactive'))
        const active = reviews.filter((el) => el.classList.contains('active'))[0];
        const index = reviews.findIndex((el) => el === active)
        active.classList.remove('active')
        active.classList.add('inactive')
        const next = index === reviews.length -1 ? reviews[0] : reviews[index + 1]
        next.classList.add('active')
    }, 8000)
    setTimeout(() => {
      clearInterval(reviewsInterval)
    }, 120000);
  }
}