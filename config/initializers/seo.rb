# Canonical public origin for www.spinalcare.ro. Used for <link rel="canonical">,
# og:url, sitemap URLs and JSON-LD. Override with CANONICAL_HOST if the site ever moves.
Rails.application.config.x.canonical_host = ENV.fetch("CANONICAL_HOST", "www.spinalcare.ro")
Rails.application.config.x.canonical_origin = "https://#{Rails.application.config.x.canonical_host}"
