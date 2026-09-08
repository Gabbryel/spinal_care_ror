module SeoHelper
  # Absolute origin every public URL is canonicalised to (https://www.spinalcare.ro).
  def canonical_origin
    Rails.application.config.x.canonical_origin
  end

  # Self-referential canonical URL for the current request: canonical host, no query
  # string, no trailing slash (except for the root). Views can override it with
  # `content_for :canonical_url, "https://www.spinalcare.ro/..."` (paginated or
  # duplicate pages).
  def canonical_url
    return content_for(:canonical_url) if content_for?(:canonical_url)

    canonical_url_for(request.path)
  end

  # Builds a canonical absolute URL from a path.
  def canonical_url_for(path)
    normalized = path.to_s.split("?").first.to_s.sub(%r{/+\z}, "")
    normalized = "/#{normalized}" unless normalized.start_with?("/")
    normalized == "/" ? "#{canonical_origin}/" : "#{canonical_origin}#{normalized}"
  end
end

module SeoHelper
  CLINIC_NAME = "Clinica Spinal Care Bacău".freeze
  CLINIC_PHONE = "+40374554344".freeze
  CLINIC_PHONE_DISPLAY = "0374 554 344".freeze
  SOCIAL_PROFILES = [
    "https://www.facebook.com/SpinalCareBacau",
    "https://www.instagram.com/spinalcarebacau"
  ].freeze

  # ---------------------------------------------------------------------------
  # Titles and descriptions
  # ---------------------------------------------------------------------------

  BRAND = "Clinica Spinal Care".freeze
  TITLE_MAX = 65
  TITLE_TRAILING_STOPWORDS = /\s+(de|și|si|pentru|a|la|cu|în|in|pe|din|sau|prin|al|ale)\z/i
  DESCRIPTION_MIN = 70
  DESCRIPTION_MAX = 155

  # "<Subject> Bacău | Clinica Spinal Care". "Bacău" is never dropped: when
  # the subject is long the brand is shortened to "Spinal Care", then the
  # subject itself is cut at a word boundary (never ending on a stopword) so
  # the whole title stays within TITLE_MAX. An explicit seo_title (short,
  # editor-provided) replaces the subject entirely.
  def page_title(subject, seo_title: nil)
    subject = seo_title.to_s.squish.presence || subject.to_s.squish
    full = "#{subject} Bacău | #{BRAND}"
    return full if full.length <= 60

    short = "#{subject} Bacău | Spinal Care"
    return short if short.length <= TITLE_MAX

    room = TITLE_MAX - " Bacău | Spinal Care".length
    "#{shorten_at_word(subject, room)} Bacău | Spinal Care"
  end

  # Meta description derived from a record's own rich text (first ~155
  # characters, cut at a word boundary). When the record's own text is
  # missing or too short to be useful (< 70 chars, e.g. image-only content),
  # the record-specific fallback is used, with the short own text appended.
  def meta_description_for(rich_text, fallback = nil)
    excerpt = plain_text_excerpt(rich_text, DESCRIPTION_MAX)
    return excerpt if excerpt.length >= DESCRIPTION_MIN

    base = plain_text_excerpt(fallback, DESCRIPTION_MAX)
    return base if excerpt.empty?

    truncate("#{base} #{excerpt}".squish, length: DESCRIPTION_MAX, separator: " ", omission: "…")
  end

  # Cuts text at a word boundary within `limit` characters, no ellipsis,
  # dropping a dangling stopword ("... de", "... și").
  def shorten_at_word(text, limit)
    text = text.to_s.squish
    return text if text.length <= limit

    cut = text[0, limit + 1]
    cut = cut[0, cut.rindex(" ") || limit]
    cut = cut[0, cut.rindex("(")] if cut.count("(") > cut.count(")")
    cut = cut.sub(/[\s,;:–-]+\z/, "")
    cut = cut.sub(TITLE_TRAILING_STOPWORDS, "") while cut =~ TITLE_TRAILING_STOPWORDS
    cut
  end

  # ---------------------------------------------------------------------------
  # JSON-LD
  # ---------------------------------------------------------------------------

  # Renders a <script type="application/ld+json"> tag. "</" is escaped so a
  # description containing "</script>" cannot break out of the tag.
  def json_ld_tag(data)
    return if data.blank?

    json = JSON.generate(data).gsub("</", "<\\/")
    content_tag(:script, json.html_safe, type: "application/ld+json")
  end

  def clinic_json_ld_id
    "#{canonical_origin}/#clinic"
  end

  # Organisation block emitted on every page. Locations come from
  # ContactCardsHelper#contact_cards, the same source the footer uses.
  # Opening hours are not stored anywhere in the app, so no
  # openingHoursSpecification is emitted rather than inventing one.
  def clinic_json_ld
    departments = contact_cards.map do |card|
      {
        "@type" => "MedicalClinic",
        "name" => "#{CLINIC_NAME} – #{card[:name]}",
        "telephone" => e164_phone(card[:tel_fix]),
        "address" => postal_address(card[:address])
      }
    end

    {
      "@context" => "https://schema.org",
      "@type" => "MedicalClinic",
      "@id" => clinic_json_ld_id,
      "name" => CLINIC_NAME,
      "url" => "#{canonical_origin}/",
      "telephone" => CLINIC_PHONE,
      "image" => DEFAULT_META["meta_image"],
      "sameAs" => SOCIAL_PROFILES,
      "address" => departments.first["address"],
      "department" => departments
    }
  end

  def clinic_json_ld_reference
    { "@type" => "MedicalClinic", "@id" => clinic_json_ld_id, "name" => CLINIC_NAME, "url" => "#{canonical_origin}/" }
  end

  # Profile pages. Doctors are a single-typed Physician (schema.org's
  # Physician is a MedicalBusiness, so it carries the academic title in the
  # name and links to the clinic via parentOrganization); the rest of the
  # team is a Person with jobTitle/worksFor.
  def member_json_ld(member)
    physician = member.profession&.slug == "medic"
    title = member.academic_title.to_s.strip
    title = "" if title == "-"
    data = {
      "@context" => "https://schema.org",
      "@type" => physician ? "Physician" : "Person",
      "name" => physician ? [title, full_name(member)].reject(&:empty?).join(" ") : full_name(member),
      "url" => canonical_url
    }
    if physician
      data["medicalSpecialty"] = member.specialty.name if member.specialty
      data["parentOrganization"] = clinic_json_ld_reference
    else
      data["honorificPrefix"] = title if title.present?
      job_title = [translate_profession(member.profession_name), member.doctor_grade].map(&:to_s).map(&:strip).reject(&:empty?).join(" ")
      data["jobTitle"] = job_title if job_title.present?
      data["worksFor"] = clinic_json_ld_reference
    end
    data["image"] = cl_image_path(member.photo.key, width: 600, crop: :limit, fetch_format: :auto) if member.photo.attached?
    description = plain_text_excerpt(member.description, 300)
    data["description"] = description if description.present?
    data
  end

  # Specialty pages: one MedicalProcedure per medical service the clinic
  # actually lists for that specialty. Nothing is emitted for a specialty
  # without services.
  def specialty_procedures_json_ld(specialty)
    services = specialty.medical_services.sort_by(&:name)
    return if services.empty?

    procedures = services.map do |service|
      item = {
        "@type" => "MedicalProcedure",
        "name" => service.name.to_s.strip,
        "url" => canonical_url_for("/specialitati-medicale/#{specialty.slug}")
      }
      description = plain_text_excerpt(service.description, 300)
      item["description"] = description if description.present?
      item
    end

    { "@context" => "https://schema.org", "@graph" => procedures }
  end

  # crumbs: [[name, path], ...] in order, the current page last.
  def breadcrumb_json_ld(crumbs)
    {
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => crumbs.each_with_index.map do |(name, path), index|
        { "@type" => "ListItem", "position" => index + 1, "name" => name, "item" => canonical_url_for(path) }
      end
    }
  end

  # Plain-text excerpt of an ActionText rich text (or a string), whitespace
  # collapsed, cut at a word boundary.
  def plain_text_excerpt(rich_text, limit)
    text = rich_text.respond_to?(:to_plain_text) ? rich_text.to_plain_text : strip_tags(rich_text.to_s)
    # ActionText renders attachments as "[Image]" / "[file.pdf]" placeholders.
    text = text.to_s.gsub(/\[[^\]]*\]/, " ").squish
    return "" if text.empty?

    truncate(text, length: limit, separator: " ", omission: "…")
  end

  private

  def postal_address(street)
    {
      "@type" => "PostalAddress",
      "streetAddress" => street.to_s.sub(/,?\s*Bacău\z/, "").strip,
      "addressLocality" => "Bacău",
      "addressRegion" => "Bacău",
      "addressCountry" => "RO"
    }
  end

  def e164_phone(number)
    digits = number.to_s.gsub(/\D/, "")
    digits = digits.sub(/\A0/, "40") if digits.start_with?("0")
    "+#{digits}"
  end
end
