import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    var mainContainer = document.getElementById('landing-image');
    var imageText = document.getElementById('landing-image-description');
    var images = [
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_90,w_1000/v1653807781/development/0236_cu8xqs.webp",
      ["https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_90,w_1000/v1654329520/development/btcfrzj088gsc9vxau9n1aeta4g2.webp", "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_90,w_1000/v1699776716/cabinets/www.sysphotodesign.ro_156_b2vhwx.webp", "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_90,w_1000/v1699776632/cabinets/www.sysphotodesign.ro_19_bihpcn.webp"],
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_90,w_1000/v1654682878/production/zg9bn5picn9m1th7e5narlkjej8u.webp",
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_90,w_1000/v1699776716/cabinets/www.sysphotodesign.ro_157_gxykxx.webp",
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_90,w_1000/v1718358055/cabinets/0126_vmwegk.webp",
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_90,w_1000/v1699776672/cabinets/www.sysphotodesign.ro_91_af55tg.webp",
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_90,w_1000/v1723391283/cabinets/eximia-web_v2_lnyhu8.webp"
    ];
    var texts = ["clinică medicală multidisciplinară", "medici experimentați", "kinetoterapeuți dedicați", "aparatură medicală performantă", "spitalizare de zi", "gratuit 100% prin CAS", "terapii 'Beauty' neinvazive" ];
    var showImages = () => {
      images.forEach((image, i) => {
        setTimeout(() => {
          if (typeof image === "object") {
            mainContainer.style.backgroundImage = `url(${image[Math.round(Math.random() * 2)]})`;
          } else {
            mainContainer.style.backgroundImage = `url(${image})`;
          }
          imageText.innerText = texts[i];
        }, 4000 * i )
      })
    }
      showImages();
      setInterval(showImages, 4000 * texts.length);
  }
}