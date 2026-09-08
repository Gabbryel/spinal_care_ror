require "test_helper"
require "json"
require "rake"

# Request tests for the technical SEO layer: canonical, titles, headings,
# JSON-LD, alt attributes, robots.txt, sitemap and slug redirects.
class SeoTest < ActionDispatch::IntegrationTest
  # The suite's fixtures do not cover these models; build the records inline.
  self.fixture_table_names = []

  CANONICAL = "https://www.spinalcare.ro".freeze
  GIF = Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7").freeze

  setup do
    # Bullet raises on a pre-existing N+1 (specialty photos on the homepage);
    # query optimisation is out of scope here, so silence it for these tests.
    @bullet_was_enabled = Bullet.enable?
    Bullet.enable = false

    host! "www.spinalcare.ro"
    @medic = Profession.create!(name: "medic")
    Profession.create!(name: "fiziokinetoterapeut")
    @cardio = Specialty.create!(name: "Cardiologie intervențională",
                                description: "<p>Proceduri minim invazive pentru afecțiuni ale inimii.</p>")
    @cardio.photo.attach(io: StringIO.new(GIF), filename: "cardio.gif", content_type: "image/gif")
    Specialty.create!(name: "Nutriție")
    MedicalService.create!(name: "Consultație și diagnostic", price: 200, specialty: @cardio)
    @member = Member.create!(first_name: "Ștefan", last_name: "Moisei", profession: @medic, specialty: @cardio,
                             academic_title: "dr.", doctor_grade: "primar", has_own_page: true, selected: true, order: 1)
    @member.photo.attach(io: StringIO.new(GIF), filename: "moisei.gif", content_type: "image/gif")
    @fact = Fact.create!(name: "Drepturile pacientului", description: "<p>Fiecare pacient are dreptul la informare.</p>")
  end

  teardown do
    Bullet.enable = @bullet_was_enabled
  end

  PUBLIC_PAGES = lambda do |t|
    ["/", "/echipa", "/servicii-medicale", "/specialitati-medicale",
     "/specialitati-medicale/#{t.cardio.slug}", "/echipa/#{t.member.slug}"]
  end

  attr_reader :cardio, :member

  # --- 1. canonical ---------------------------------------------------------

  test "slugs transliterate Romanian diacritics" do
    assert_equal "cardiologie-interventionala", @cardio.slug
    assert_equal "stefan-moisei", @member.slug
    assert_equal "nutritie", Specialty.find_by(name: "Nutriție").slug
  end

  test "canonical is self-referential on www.spinalcare.ro without query string or trailing slash" do
    get "/"
    assert_select "link[rel=canonical][href=?]", "#{CANONICAL}/", count: 1
    assert_select "meta[property='og:url'][content=?]", "#{CANONICAL}/"

    get "/echipa/?utm_source=facebook"
    assert_response :success
    assert_select "link[rel=canonical][href=?]", "#{CANONICAL}/echipa", count: 1

    get "/specialitati-medicale/#{@cardio.slug}"
    assert_select "link[rel=canonical][href=?]", "#{CANONICAL}/specialitati-medicale/#{@cardio.slug}", count: 1
  end

  # --- 6. titles and descriptions -----------------------------------------

  test "every public page has a unique title and meta description and no keywords tag" do
    titles = {}
    descriptions = {}
    PUBLIC_PAGES.call(self).each do |path|
      get path
      assert_response :success, path
      titles[path] = css_select("title").first.text
      descriptions[path] = css_select("meta[name=description]").first["content"]
      assert_select "meta[name=keywords]", count: 0
      assert titles[path].length <= 70, "#{path} title too long: #{titles[path]}"
      assert descriptions[path].present?, "#{path} has no description"
    end
    assert_equal titles.values.uniq.size, titles.size, "duplicate titles: #{titles}"
    assert_equal descriptions.values.uniq.size, descriptions.size, "duplicate descriptions: #{descriptions}"
    assert_equal "Servicii medicale Bacău | Clinica Spinal Care", titles["/servicii-medicale"]
    assert_equal "Kinetoterapie și recuperare medicală în Bacău | Spinal Care", titles["/"]
    assert_match(/recuperare medicală, kinetoterapie/, descriptions["/"])
    assert descriptions["/"].length.between?(120, 155)
    assert_equal "Cardiologie intervențională Bacău | Clinica Spinal Care", titles["/specialitati-medicale/#{@cardio.slug}"]
    assert_match(/Proceduri minim invazive/, descriptions["/specialitati-medicale/#{@cardio.slug}"])
  end

  test "open graph and twitter tags mirror the page title and description" do
    get "/specialitati-medicale/#{@cardio.slug}"
    title = css_select("title").first.text
    description = css_select("meta[name=description]").first["content"]
    assert_select "meta[property='og:title'][content=?]", title
    assert_select "meta[name='twitter:title'][content=?]", title
    assert_select "meta[property='og:description'][content=?]", description
    assert_select "meta[name='twitter:description'][content=?]", description
  end

  # --- 7. headings -----------------------------------------------------------

  test "every public page has exactly one h1" do
    PUBLIC_PAGES.call(self).each do |path|
      get path
      assert_select "h1", count: 1
    end
    get "/"
    assert_select "h1", text: "Clinica Spinal Care Bacău"
    assert_select "h1", text: /Programări/, count: 0
  end

  # --- 8. alt attributes -----------------------------------------------------

  test "every image on the public pages has an alt attribute" do
    ["/", "/specialitati-medicale", "/servicii-medicale", "/info-pacient-index"].each do |path|
      get path
      images = css_select("img")
      assert images.any?, "#{path} renders no images"
      missing = images.reject { |img| img.key?("alt") }
      assert_empty missing.map(&:to_s), "#{path} has images without alt"
    end
  end

  # --- 5. JSON-LD -------------------------------------------------------------

  test "homepage emits a MedicalClinic with two departments and no ratings" do
    get "/"
    blocks = json_ld_blocks
    clinic = blocks.find { |b| b["@type"] == "MedicalClinic" }
    assert clinic, "no MedicalClinic block"
    assert_equal "#{CANONICAL}/", clinic["url"]
    assert_equal "+40374554344", clinic["telephone"]
    assert_equal 2, clinic["department"].size
    streets = clinic["department"].map { |d| d.dig("address", "streetAddress") }
    assert_includes streets, "Str. Mihai Eminescu, nr. 1bis"
    assert_includes streets, "Str. Nicolae Titulescu nr. 31"
    assert clinic["department"].all? { |d| d.dig("address", "@type") == "PostalAddress" && d.dig("address", "addressLocality") == "Bacău" }
    refute_includes response.body, "AggregateRating"
  end

  test "doctor profile emits Physician and BreadcrumbList" do
    get "/echipa/#{@member.slug}"
    blocks = json_ld_blocks
    physician = blocks.find { |b| b["@type"] == "Physician" }
    assert physician, "no single-typed Physician block"
    assert_equal 1, blocks.count { |b| Array(b["@type"]).intersect?(%w[Physician Person]) }, "one entity block per profile"
    assert_equal "dr. Ștefan Moisei", physician["name"]
    assert_equal "Cardiologie intervențională", physician["medicalSpecialty"]
    assert_match %r{res\.cloudinary\.com}, physician["image"]
    assert_equal "MedicalClinic", physician.dig("parentOrganization", "@type")
    assert_equal "#{CANONICAL}/#clinic", physician.dig("parentOrganization", "@id")
    assert_nil physician["worksFor"]
    assert_nil physician["honorificPrefix"]

    crumbs = blocks.find { |b| b["@type"] == "BreadcrumbList" }
    assert_equal ["Acasă", "Echipa medicală", "dr. Ștefan Moisei"], crumbs["itemListElement"].map { |i| i["name"] }
    assert_equal "#{CANONICAL}/echipa/#{@member.slug}", crumbs["itemListElement"].last["item"]
  end

  test "non-doctor profiles emit a Person with jobTitle and worksFor" do
    kineto = Profession.find_by!(name: "fiziokinetoterapeut")
    member = Member.create!(first_name: "Andreea", last_name: "Popa", profession: kineto, has_own_page: true)
    get "/echipa/#{member.slug}"
    person = json_ld_blocks.find { |b| b["@type"] == "Person" }
    assert person, "no Person block"
    assert_equal "Andreea Popa", person["name"]
    assert_equal "Fiziokinetoterapeut", person["jobTitle"]
    assert_equal "#{CANONICAL}/#clinic", person.dig("worksFor", "@id")
    assert_nil person["medicalSpecialty"]
  end

  test "specialty page emits BreadcrumbList and MedicalProcedure entries" do
    get "/specialitati-medicale/#{@cardio.slug}"
    blocks = json_ld_blocks
    crumbs = blocks.find { |b| b["@type"] == "BreadcrumbList" }
    assert_equal [1, 2, 3], crumbs["itemListElement"].map { |i| i["position"] }
    assert_equal "#{CANONICAL}/specialitati-medicale", crumbs["itemListElement"][1]["item"]

    procedures = blocks.find { |b| b["@graph"] }
    assert procedures, "no MedicalProcedure graph"
    assert_equal ["MedicalProcedure"], procedures["@graph"].map { |p| p["@type"] }.uniq
    assert_equal ["Consultație și diagnostic"], procedures["@graph"].map { |p| p["name"] }
  end

  # --- 3. robots.txt ----------------------------------------------------------

  test "robots.txt allows the public site, blocks the admin areas and names the sitemap" do
    get "/robots.txt"
    assert_response :success
    assert_match(/^User-agent: \*$/, response.body)
    assert_match(/^Allow: \/$/, response.body)
    assert_match(%r{^Disallow: /dashboard$}, response.body)
    assert_match(%r{^Disallow: /users/$}, response.body)
    assert_match(%r{^Sitemap: https://www\.spinalcare\.ro/sitemap\.xml$}, response.body)
    refute_match(/example\.com/, response.body)
  end

  # --- 4. sitemap -------------------------------------------------------------

  test "sitemap lists each page once on the canonical host with real lastmod and realistic changefreq" do
    get "/sitemap.xml"
    assert_response :success
    assert_equal "application/xml", response.media_type
    xml = Nokogiri::XML(response.body)
    xml.remove_namespaces!
    urls = xml.xpath("//url")
    locs = urls.map { |u| u.at("loc").text }

    assert_equal 1, locs.count("#{CANONICAL}/"), "homepage must appear exactly once"
    assert_equal locs.uniq, locs, "duplicate URLs in sitemap"
    assert locs.all? { |l| l.start_with?("#{CANONICAL}/") }, "non-canonical host in sitemap: #{locs}"
    assert_includes locs, "#{CANONICAL}/specialitati-medicale/#{@cardio.slug}"
    assert_includes locs, "#{CANONICAL}/echipa/#{@member.slug}"
    assert_includes locs, "#{CANONICAL}/info-pacient/#{@fact.slug}"
    assert_empty locs.grep(%r{/servicii-medicale/.}), "retired per-specialty price pages must not be in the sitemap"

    assert_empty urls.map { |u| u.at("changefreq").text }.select { |f| f == "daily" }
    member_entry = urls.find { |u| u.at("loc").text.end_with?("/echipa/#{@member.slug}") }
    assert_equal "monthly", member_entry.at("changefreq").text
    assert_equal @member.updated_at.to_date.iso8601, member_entry.at("lastmod").text
    assert_equal "1.0", urls.first.at("priority").text
  end

  # --- 9. slug redirects ------------------------------------------------------

  test "seo:fix_slugs regenerates corrupted slugs and old URLs answer with a 301" do
    @cardio.update_column(:slug, "cardiologie-interven-ionala")
    @member.update_column(:slug, "tefan-moisei")
    @fact.update_column(:slug, "drepturile-pacien-ilor")

    Rails.application.load_tasks unless Rake::Task.task_defined?("seo:fix_slugs")
    silence_stream($stdout) { Rake::Task["seo:fix_slugs"].execute }

    assert_equal "cardiologie-interventionala", @cardio.reload.slug
    assert_equal "stefan-moisei", @member.reload.slug
    assert_equal "drepturile-pacientului", @fact.reload.slug
    assert_equal 3, SlugRedirect.count

    get "/specialitati-medicale/cardiologie-interven-ionala"
    assert_redirected_to "/specialitati-medicale/cardiologie-interventionala"
    assert_response :moved_permanently

    get "/servicii-medicale/cardiologie-interven-ionala?ref=x"
    assert_redirected_to "/specialitati-medicale/cardiologie-interventionala?ref=x"
    assert_response :moved_permanently

    get "/echipa/tefan-moisei"
    assert_redirected_to "/echipa/stefan-moisei"
    assert_response :moved_permanently

    get "/info-pacient/drepturile-pacien-ilor"
    assert_redirected_to "/info-pacient/drepturile-pacientului"
    assert_response :moved_permanently

    # The corrected slugs render normally and the sitemap only knows the new ones.
    get "/specialitati-medicale/cardiologie-interventionala"
    assert_response :success
    get "/sitemap.xml"
    refute_includes response.body, "interven-ionala"
  end

  test "renaming a record keeps a redirect from its previous slug" do
    @cardio.update!(name: "Cardiologie")
    assert_equal "cardiologie", @cardio.reload.slug
    get "/specialitati-medicale/cardiologie-interventionala"
    assert_redirected_to "/specialitati-medicale/cardiologie"
    assert_response :moved_permanently
  end

  # --- round 2 ----------------------------------------------------------------

  test "specialties without services emit exactly one BreadcrumbList and no procedures" do
    empty = Specialty.create!(name: "Pneumologie")
    get "/specialitati-medicale/#{empty.slug}"
    assert_response :success
    blocks = json_ld_blocks
    assert_equal 1, blocks.count { |b| b["@type"] == "BreadcrumbList" }
    assert_equal 0, blocks.count { |b| b["@graph"] }
    assert_equal 1, response.body.scan("BreadcrumbList").size
  end

  test "retired /servicii-medicale/<slug> answers 301 to the specialty page" do
    get "/servicii-medicale/#{@cardio.slug}"
    assert_redirected_to "/specialitati-medicale/#{@cardio.slug}"
    assert_response :moved_permanently

    get "/servicii-medicale/nu-exista"
    assert_redirected_to "/servicii-medicale"
    assert_response :moved_permanently

    get "/servicii-medicale"
    assert_response :success
  end

  test "MedicalProcedure entries point at the specialty page" do
    get "/specialitati-medicale/#{@cardio.slug}"
    procedures = json_ld_blocks.find { |b| b["@graph"] }
    assert_equal ["#{CANONICAL}/specialitati-medicale/#{@cardio.slug}"], procedures["@graph"].map { |p| p["url"] }.uniq
  end

  test "seo:restructure_recovery retires Fiziokinetoterapie with a 301 and attaches physiotherapists" do
    kineto = Profession.find_by!(name: "fiziokinetoterapeut")
    target = Specialty.create!(name: "Fizioterapie și Recuperare medicală")
    retired = Specialty.create!(name: "Fiziokinetoterapie")
    unassigned = Member.create!(first_name: "Ioana", last_name: "Măciucă", profession: kineto)
    inactive = Member.create!(first_name: "Anca", last_name: "Veche", profession: kineto, is_active: false)

    Rails.application.load_tasks unless Rake::Task.task_defined?("seo:restructure_recovery")
    silence_stream($stdout) { Rake::Task["seo:restructure_recovery"].execute }

    assert_nil Specialty.find_by(slug: retired.slug)
    assert_equal target, unassigned.reload.specialty
    assert_nil inactive.reload.specialty
    assert_equal @cardio, @member.reload.specialty, "members that already have a specialty are untouched"

    get "/specialitati-medicale/fiziokinetoterapie"
    assert_redirected_to "/specialitati-medicale/#{target.slug}"
    assert_response :moved_permanently
    get "/servicii-medicale/fiziokinetoterapie"
    assert_redirected_to "/specialitati-medicale/#{target.slug}"
    assert_response :moved_permanently
  end

  test "profiles without their own page are noindex, real profiles are not" do
    bare = Member.create!(first_name: "Adrian", last_name: "Popa", profession: @medic, has_own_page: false)
    get "/echipa/#{bare.slug}"
    assert_response :success
    assert_select "meta[name=robots][content='noindex, follow']", count: 1

    get "/echipa/#{@member.slug}"
    assert_select "meta[name=robots]", count: 0
    get "/"
    assert_select "meta[name=robots]", count: 0
  end

  test "below-the-fold images are lazy and the hero image is preloaded" do
    get "/"
    assert_select "link[rel=preload][as=image][fetchpriority=high]", count: 1
    images = css_select("img")
    lazy = images.select { |img| img["loading"] == "lazy" }
    assert lazy.size >= 2, "expected lazy images on the homepage"
    assert lazy.all? { |img| img["decoding"] == "async" }
    eager_alts = images.reject { |img| img["loading"] == "lazy" }.map { |img| img["alt"] }
    assert_includes eager_alts, "Spinal Care logo"
    assert_includes eager_alts, "15 ani Spinal Care"
    specialty_img = images.find { |img| img["alt"] == @cardio.name }
    assert specialty_img && specialty_img["loading"] == "lazy", "specialty card image should be lazy"
  end

  private

  def json_ld_blocks
    css_select("script[type='application/ld+json']").map { |node| JSON.parse(node.text) }
  end

  def silence_stream(stream)
    old = stream.dup
    stream.reopen(File::NULL)
    yield
  ensure
    stream.reopen(old)
  end
end
