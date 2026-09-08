# The homepage hero slideshow. The first slide is rendered server-side as a
# real <img> with fetchpriority="high" (it is the page's LCP element); the
# Stimulus controller landingimage reads the full list from data attributes
# and crossfades through it.
module HeroHelper
  HERO_SLIDES = [
    "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1653807781/development/0236_cu8xqs.webp",
    [
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1654329520/development/btcfrzj088gsc9vxau9n1aeta4g2.webp",
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1699776716/cabinets/www.sysphotodesign.ro_156_b2vhwx.webp",
      "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1699776632/cabinets/www.sysphotodesign.ro_19_bihpcn.webp"
    ],
    "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1654682878/production/zg9bn5picn9m1th7e5narlkjej8u.webp",
    "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1699776716/cabinets/www.sysphotodesign.ro_157_gxykxx.webp",
    "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1718358055/cabinets/0126_vmwegk.webp",
    "https://res.cloudinary.com/www-spinalcare-ro/image/upload/c_scale,q_auto:good,w_1500/v1699776672/cabinets/www.sysphotodesign.ro_91_af55tg.webp"
  ].freeze

  HERO_CAPTIONS = [
    "clinică medicală multidisciplinară",
    "medici experimentați",
    "kinetoterapeuți dedicați",
    "aparatură medicală performantă",
    "spitalizare de zi",
    "gratuit 100% prin CAS"
  ].freeze

  def hero_first_slide
    HERO_SLIDES.first
  end
end
