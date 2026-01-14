import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.mainContainer = document.getElementById("landing-image");
    this.imageText = document.getElementById("landing-image-description");
    this.currentIndex = 0;

    this.images = [
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1653807781/development/0236_cu8xqs.webp",
      [
        "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1654329520/development/btcfrzj088gsc9vxau9n1aeta4g2.webp",
        "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1699776716/cabinets/www.sysphotodesign.ro_156_b2vhwx.webp",
        "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1699776632/cabinets/www.sysphotodesign.ro_19_bihpcn.webp",
      ],
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1654682878/production/zg9bn5picn9m1th7e5narlkjej8u.webp",
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1699776716/cabinets/www.sysphotodesign.ro_157_gxykxx.webp",
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1718358055/cabinets/0126_vmwegk.webp",
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1699776672/cabinets/www.sysphotodesign.ro_91_af55tg.webp",
    ];

    this.texts = [
      "clinică medicală multidisciplinară",
      "medici experimentați",
      "kinetoterapeuți dedicați",
      "aparatură medicală performantă",
      "spitalizare de zi",
      "gratuit 100% prin CAS",
    ];

    // Create two layers for crossfading
    this.createImageLayers();

    // Show first image immediately
    this.showImage(0);

    // Start the slideshow
    this.intervalId = setInterval(() => this.nextImage(), 4000);
  }

  disconnect() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }
  }

  createImageLayers() {
    // Clear existing content
    this.mainContainer.innerHTML = "";

    // Create two image layers for crossfading
    this.layer1 = document.createElement("div");
    this.layer1.className = "hero-image-layer";
    this.layer1.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background-size: cover;
      background-position: center;
      background-repeat: no-repeat;
      opacity: 1;
      transition: opacity 1s ease-in-out;
    `;

    this.layer2 = document.createElement("div");
    this.layer2.className = "hero-image-layer";
    this.layer2.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background-size: cover;
      background-position: center;
      background-repeat: no-repeat;
      opacity: 0;
      transition: opacity 1s ease-in-out;
    `;

    this.mainContainer.appendChild(this.layer1);
    this.mainContainer.appendChild(this.layer2);

    this.activeLayer = this.layer1;
    this.inactiveLayer = this.layer2;
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

    // Preload the next image
    const img = new Image();
    img.src = imageUrl;

    img.onload = () => {
      // Set image on inactive layer
      this.inactiveLayer.style.backgroundImage = `url(${imageUrl})`;

      // Crossfade images
      this.activeLayer.style.opacity = "0";
      this.inactiveLayer.style.opacity = "1";

      // Update text after brief delay and fade in
      setTimeout(() => {
        this.imageText.innerText = this.texts[index];
        this.imageText.style.opacity = "1";
      }, 500);

      // Swap active/inactive layers
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
