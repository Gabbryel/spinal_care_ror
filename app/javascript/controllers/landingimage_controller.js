import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { images: Array, captions: Array };

  connect() {
    this.mainContainer = this.element;
    this.imageText = document.getElementById("landing-image-description");
    this.currentIndex = 0;

    // Slides and captions come from HeroHelper via data attributes; the
    // fallbacks keep the slideshow alive if the attributes are missing.
    this.images = this.imagesValue.length ? this.imagesValue : [
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1653807781/development/0236_cu8xqs.webp",
    ];
    this.texts = this.captionsValue.length ? this.captionsValue : ["clinică medicală multidisciplinară"];

    this.createImageLayers();

    // The first slide is already rendered server-side as the LCP <img>;
    // only the caption needs to appear.
    this.imageText.innerText = this.texts[0];
    this.imageText.style.opacity = "1";

    this.intervalId = setInterval(() => this.nextImage(), 4000);
  }

  disconnect() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }
  }

  createImageLayers() {
    // Layer 1 is the server-rendered <img class="hero-image-layer"> (eager,
    // fetchpriority=high). Layer 2 is created here for the crossfade.
    this.layer1 = this.mainContainer.querySelector("img.hero-image-layer");
    if (!this.layer1) {
      this.layer1 = this.createLayer();
      this.layer1.src = this.getImageUrl(this.images[0]);
      this.mainContainer.appendChild(this.layer1);
    }

    this.layer2 = this.createLayer();
    this.layer2.style.opacity = "0";
    this.mainContainer.appendChild(this.layer2);

    this.activeLayer = this.layer1;
    this.inactiveLayer = this.layer2;
  }

  createLayer() {
    const img = document.createElement("img");
    img.className = "hero-image-layer";
    img.alt = "";
    img.decoding = "async";
    return img;
  }

  getImageUrl(image) {
    if (typeof image === "object") {
      return image[Math.floor(Math.random() * image.length)];
    }
    return image;
  }

  showImage(index) {
    const imageUrl = this.getImageUrl(this.images[index]);

    // Fade out text first
    this.imageText.style.opacity = "0";

    // Preload the next image, then swap it into the hidden layer and crossfade
    const img = new Image();
    img.src = imageUrl;

    img.onload = () => {
      this.inactiveLayer.src = imageUrl;

      this.activeLayer.style.opacity = "0";
      this.inactiveLayer.style.opacity = "1";

      setTimeout(() => {
        this.imageText.innerText = this.texts[index % this.texts.length];
        this.imageText.style.opacity = "1";
      }, 500);

      [this.activeLayer, this.inactiveLayer] = [
        this.inactiveLayer,
        this.activeLayer,
      ];
    };
  }

  nextImage() {
    this.currentIndex = (this.currentIndex + 1) % this.images.length;
    this.showImage(this.currentIndex);
  }
}
