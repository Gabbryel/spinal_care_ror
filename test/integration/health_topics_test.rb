require "test_helper"

# Condition and procedure pages: public pages with their doctors, prices,
# FAQ and structured data; drafts kept off the site; links from specialty
# pages, menus and the sitemap; and the dashboard that writes them.
class HealthTopicsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    Rails.cache.clear
    host! "www.spinalcare.ro"
    Rails.application.reload_routes_unless_loaded
    @bullet_was_enabled = Bullet.enable?
    Bullet.enable = false
    medic = Profession.create!(name: "medic")
    @neuro = Specialty.create!(name: "Neurochirurgie", description: "<p>x</p>", is_active: true)
    @ortho = Specialty.create!(name: "Ortopedie", description: "<p>x</p>", is_active: true)
    @doctor = Member.create!(first_name: "Costin", last_name: "Pahonțu", profession: medic, specialty: @neuro, academic_title: "dr.",
                             doctor_grade: "specialist", has_own_page: true, is_active: true, order: 1)
    @service = MedicalService.create!(name: "Consultație neurochirurgie", price: 430, specialty: @neuro)
    @topic = HealthTopic.create!(kind: "afectiune", name: "Hernie de disc", summary: "Hernia de disc apare când discul dintre vertebre apasă pe un nerv. Se tratează de cele mai multe ori fără operație.",
                                 body: "<h2>Simptome</h2><p>Durere de spate care coboară pe picior.</p>", specialty_ids: [@neuro.id],
                                 medical_service_ids: [@service.id], faqs_text: "Se operează?\nRar; de obicei nu.\n\nCât durează?\nCâteva săptămâni.",
                                 published: true)
    @admin = User.create!(email: "admin@spinalcare.ro", password: "secret-password-1", admin: true)
  end

  teardown do
    Bullet.enable = @bullet_was_enabled
  end

  test "a published condition page shows its text, doctors, prices, questions and structured data" do
    get "/afectiuni/hernie-de-disc"
    assert_response :success
    assert_select "h1", "Hernie de disc"
    assert_select ".ht-lead", /discul dintre vertebre/
    assert_select ".ht-body h3", "Simptome", "rich-text headings are demoted under the page's h1"
    assert_select ".ht-people a[href='/echipa/#{@doctor.slug}']", /dr\. Costin Pahonțu/
    assert_select ".ht-services li", /Consultație neurochirurgie\s+430 lei/
    assert_select ".ht-faq details", 2
    assert_select ".specialty-cta", 2
    assert_select "title", "Hernie de disc Bacău | Clinica Spinal Care"
    assert_select "meta[name=description][content^=?]", "Hernia de disc apare când discul"

    graphs = css_select("script[type='application/ld+json']").map { |n| JSON.parse(n.text) }
    graph = graphs.find { |g| g["@graph"] }["@graph"]
    assert_equal "MedicalCondition", graph[0]["@type"]
    assert_equal "https://www.spinalcare.ro/afectiuni/hernie-de-disc", graph[0]["url"]
    assert_equal ["Se operează?", "Cât durează?"], graph[1]["mainEntity"].map { |q| q["name"] }
    assert graphs.any? { |g| g["@type"] == "BreadcrumbList" }
  end

  test "a procedure lives under /proceduri and a draft is 404 except to admins" do
    draft = HealthTopic.create!(kind: "procedura", name: "Ecografie Doppler", specialty_ids: [@ortho.id])
    get "/proceduri/ecografie-doppler"
    assert_response :not_found
    get "/afectiuni/ecografie-doppler"
    assert_response :not_found, "the kind is part of the address"

    sign_in @admin
    get "/proceduri/ecografie-doppler"
    assert_response :success
    assert_select ".ht-draft", /Ciornă/
    assert_select "meta[name=robots][content='noindex, nofollow']"

    draft.update!(published: true)
    sign_out :user
    get "/proceduri/ecografie-doppler"
    assert_response :success
    assert_equal "MedicalProcedure", css_select("script[type='application/ld+json']").map { |n| JSON.parse(n.text) }.find { |g| g["@type"] == "MedicalProcedure" }["@type"]
  end

  test "the specialty page lists its published topics, and the hub groups them by specialty" do
    HealthTopic.create!(kind: "procedura", name: "Infiltrație", specialty_ids: [@neuro.id]) # draft
    get "/specialitati-medicale/#{@neuro.slug}"
    assert_select ".specialty-topics a.ht-card", 1
    assert_select ".specialty-topics a[href='/afectiuni/hernie-de-disc']"

    get "/afectiuni-si-proceduri"
    assert_response :success
    assert_select ".ht-group h2", /Neurochirurgie/
    assert_select ".ht-group a.ht-card[href='/afectiuni/hernie-de-disc']"
    assert_select ".ht-group a.ht-card", 1, "drafts stay off the hub"
  end

  test "menus and the sitemap link to the topics only once one is published" do
    get "/"
    assert_select ".dropdown-menu a[href='/afectiuni-si-proceduri']"
    get "/sitemap.xml"
    assert_includes response.body, "https://www.spinalcare.ro/afectiuni-si-proceduri"
    assert_includes response.body, "https://www.spinalcare.ro/afectiuni/hernie-de-disc"

    @topic.update!(published: false)
    get "/"
    assert_select ".dropdown-menu a[href='/afectiuni-si-proceduri']", 0
    get "/sitemap.xml"
    refute_includes response.body, "afectiuni"
  end

  test "admins write a page: a suggestion becomes a linked draft, then it is edited and published" do
    sign_in @admin
    get "/dashboard/afectiuni"
    assert_response :success
    assert_select ".ht-suggestions button", { text: "Lombosciatică", count: 0 }, "suggestions only for the clinic's specialties"
    assert_select ".ht-suggestions form input[name=name][value='Hernie de disc']", 0, "an existing page is not suggested again"

    post "/dashboard/afectiuni/sugestie", params: { name: "Scolioză" }
    scoliosis = HealthTopic.find_by!(name: "Scolioză")
    assert_equal ["Ortopedie"], scoliosis.specialties.map(&:name)
    assert_not scoliosis.published
    assert_redirected_to "/dashboard/afectiuni/#{scoliosis.id}/editare"

    post "/dashboard/afectiuni/sugestie", params: { service_id: @service.id }
    procedure = HealthTopic.find_by!(kind: "procedura", name: "Consultație neurochirurgie")
    assert_equal [@service.id], procedure.medical_service_ids

    patch "/dashboard/afectiuni/#{scoliosis.id}", params: { health_topic: { summary: "Deviația laterală a coloanei.", body: "<p>Text</p>", published: "1", specialty_ids: [@ortho.id] } }
    assert scoliosis.reload.published
    assert scoliosis.published_at
    get "/afectiuni/scolioza"
    assert_response :success
  end

  test "text pasted into a numbered list is unwrapped, real lists are kept" do
    topic = HealthTopic.create!(name: "Lombosciatică", body: <<~HTML)
      <ol><li><br></li><li><h2>Pe scurt</h2></li><li>Primul paragraf.<br>Al doilea rând.</li><li><h2>Simptome</h2></li><li>Durerea apare:<ul><li>la mers</li><li>la ridicat</li></ul></li></ol>
    HTML
    doc = Nokogiri::HTML::DocumentFragment.parse(topic.reload.body.body.to_html)
    assert_nil doc.at_css("ol"), "the pasted numbering is gone"
    assert_equal ["Pe scurt", "Simptome"], doc.css("h2").map(&:text)
    assert_includes doc.css("div").map(&:text), "Primul paragraf.Al doilea rând."
    assert_equal ["la mers", "la ridicat"], doc.css("ul li").map(&:text), "a list inside an item stays a list"

    real = HealthTopic.create!(name: "Migrenă", body: "<div>Declanșatori:</div><ol><li>stres</li><li>somn puțin</li></ol>")
    assert_equal ["stres", "somn puțin"], Nokogiri::HTML::DocumentFragment.parse(real.reload.body.body.to_html).css("ol li").map(&:text)
  end

  test "images pasted as data URLs are uploaded and attached instead of stored in the text" do
    png = Base64.strict_encode64(File.binread(Rails.root.join("test/fixtures/files/pixel.png")))
    topic = HealthTopic.create!(name: "Scolioză", body: %(<div>Radiografie:</div><action-text-attachment content-type="image" url="data:image/png;base64,#{png}" caption="Coloana"></action-text-attachment>))
    html = topic.reload.body.body.to_html
    refute_includes html, "data:image"
    attachment = topic.body.body.attachments.first
    assert_kind_of ActiveStorage::Blob, attachment.attachable
    assert_equal "image/png", attachment.attachable.content_type
    assert_equal "Coloana", attachment.caption
  end

  test "only admins manage the pages" do
    sign_in User.create!(email: "seo@example.com", password: "secret-password-1", seo_specialist: true)
    get "/dashboard/afectiuni"
    assert_redirected_to "/dashboard/analytics"
    post "/dashboard/afectiuni/sugestie", params: { name: "Scolioză" }
    assert_not HealthTopic.exists?(name: "Scolioză")
  end
end
