require "test_helper"

# The admin activity journal (/dashboard/audit): one card per user, the
# selected user's day-by-day report in plain Romanian, period filter.
class AuditReportTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  GIF = Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7").freeze

  setup do
    host! "www.spinalcare.ro"
    Rails.application.reload_routes_unless_loaded
    @admin = User.create!(email: "admin@spinalcare.ro", password: "secret-password-1", admin: true)
    @editor = User.create!(email: "editor@spinalcare.ro", password: "secret-password-1", alias: "Ancuța")
    sign_in @admin
    AuditLog.delete_all # sign_in and record callbacks may have logged
    @now = Time.zone.now

    @service = MedicalService.create!(name: "Terapie manuală", price: 220, specialty: Specialty.create!(name: "Fizioterapie"))
    AuditLog.delete_all

    log(@editor, "login", "User", @editor.id, at: @now - 2.hours, data: { email: @editor.email }, ua: "Mozilla/5.0 Chrome/128 Safari/537.36", ip: "10.0.0.7")
    log(@editor, "update", "MedicalService", @service.id, at: @now - 1.hour,
        data: { price: [120, 220], updated_at: ["2025-01-08", "2026-09-08"] }, summary: "Price: 120 → 220", path: "/medical_services/terapie-manuala", method: "POST",
        referer: "https://www.spinalcare.ro/dashboard/servicii-medicale/fizioterapie")
    log(@editor, "destroy", "MedicalService", 999, at: @now - 50.minutes, data: { id: 999, name: "TAPE", price: 30 }, summary: "TAPE")
    log(@editor, "create", "JobPosting", 5, at: @now - 3.days, data: { title: "Medic", id: 5 })
    3.times { |i| log(@editor, "view", "MedicalService", 0, at: @now - 40.minutes + i.minutes, path: "/servicii-medicale", method: "GET", duration: 120 + i) }
    log(@admin, "update", "Member", 1, at: @now - 40.days, data: { first_name: ["Ion", "Ioan"] })
    log(@admin, "login", "User", @admin.id, at: @now - 10.days, data: { email: @admin.email })
  end

  # A photo lives in Active Storage and changes no column on the record, so a
  # photo-only save left saved_changes empty and used to be recorded nowhere.
  test "replacing only a photo is recorded and reads as a sentence" do
    profession = Profession.create!(name: "Medic", slug: "medic-audit")
    member = Member.create!(first_name: "Matei", last_name: "Popescu", profession: profession)
    member.photo.attach(io: StringIO.new(GIF), filename: "vechi.gif", content_type: "image/gif")
    AuditLog.delete_all

    assert_difference -> { AuditLog.where(auditable_type: "Member", action: "update").count }, 1 do
      patch "/members/#{member.reload.slug}", params: {
        member: { photo: Rack::Test::UploadedFile.new(StringIO.new(GIF), "image/gif", original_filename: "nou.gif") }
      }
    end
    assert_response :redirect
    assert_equal "nou.gif", member.reload.photo.filename.to_s

    log = AuditLog.where(auditable_type: "Member").last
    assert_equal @admin, log.user
    assert_includes log.description, "Matei Popescu"
    assert_equal ["vechi.gif", "nou.gif"], log.parsed_changes["photo_file"]

    get "/dashboard/audit", params: { user: @admin.id, period: "7" }
    assert_response :success
    entry = css_select(".audit-entry--update").first
    assert_includes entry.at_css(".audit-entry-text").text.squish, "a modificat membrul echipei „Matei Popescu”"
    assert_includes entry.css(".audit-entry-details li").map { |li| li.text.squish },
                    "fotografia: vechi.gif → nou.gif"
  end

  # A Trix description lives in action_text_rich_texts and only touches the
  # record, so an edit moved updated_at (the dashboard showed "Actualizat
  # acum o oră") while the journal stayed empty.
  test "editing only the description is recorded once, with both versions" do
    profession = Profession.create!(name: "Medic", slug: "medic-text")
    member = Member.create!(first_name: "Ovidiu", last_name: "Cojocariu", profession: profession,
                            description: "<div>Consultații de recuperare</div>")
    AuditLog.delete_all
    updated_before = member.reload.updated_at

    assert_difference -> { AuditLog.where(auditable_type: "Member", action: "update").count }, 1 do
      patch "/members/#{member.slug}", params: { member: { description: "<div>Consultații și terapie Schroth</div>" } }
    end
    assert_response :redirect
    member.reload
    assert_not_equal updated_before, member.updated_at, "the record is touched, which is what the dashboard shows"

    log = AuditLog.where(auditable_type: "Member").last
    assert_equal @admin, log.user
    assert_equal ["Consultații de recuperare", "Consultații și terapie Schroth"], log.parsed_changes["description_text"]

    get "/dashboard/audit", params: { user: @admin.id, period: "7" }
    entry = css_select(".audit-entry--update").first
    assert_includes entry.at_css(".audit-entry-text").text.squish, "a modificat membrul echipei „Ovidiu Cojocariu”"
    assert_includes entry.css(".audit-entry-details li").map { |li| li.text.squish },
                    "descrierea: Consultații de recuperare → Consultații și terapie Schroth"
  end

  test "a photo attached while creating a record is recorded too" do
    AuditLog.delete_all
    profession = Profession.create!(name: "Asistent", slug: "asistent-audit")
    member = Member.new(first_name: "Ana", last_name: "Ionescu", profession: profession)
    member.photo.attach(io: StringIO.new(GIF), filename: "ana.gif", content_type: "image/gif")
    Current.set(user: @admin) { member.save! }

    log = AuditLog.where(auditable_type: "Member", action: "create").last
    assert_equal "ana.gif", log.parsed_changes["photo_file"]
  end

  test "cards per user, most recently active first and selected by default" do
    get "/dashboard/audit"
    assert_response :success

    cards = css_select(".audit-user-card")
    assert_equal 2, cards.size
    assert_includes cards[0].text, "Ancuța"
    assert cards[0].matches?(".active"), "the most recently active user is selected"
    assert_includes cards[0].at_css(".audit-user-stats").text.squish, "3 modificări · 1 autentificări · 3 pagini"
    assert_includes cards[1].text, "admin@spinalcare.ro"
    assert_includes cards[1].at_css(".audit-user-stats").text.squish, "0 modificări · 1 autentificări · 0 pagini", "40-day-old edit is outside the default 30 days"
  end

  test "the selected user's report reads as sentences, grouped by day, with views folded" do
    get "/dashboard/audit", params: { user: @editor.id }
    assert_response :success

    assert_includes css_select(".audit-report-user").first.text, "Ancuța"
    tiles = css_select(".audit-summary-tile").map { |t| t.text.squish }
    assert_includes tiles[0], "3 modificări 1 creări · 1 editări · 1 ștergeri"
    assert_includes tiles[2], "2 zile active"
    assert_includes tiles[3], "3 pagini vizualizate"
    assert_includes css_select(".audit-by-type").first.text.squish, "Servicii medicale 2"

    days = css_select(".audit-day")
    assert_equal 2, days.size, "today and three days ago"
    today = days[0]
    assert_includes today.at_css(".audit-day-title").text, AuditUserReport.day_label(@now.to_date)
    texts = today.css(".audit-entry-text").map { |e| e.text.squish }
    assert_equal ["a șters serviciul medical „TAPE” #999", "a modificat serviciul medical „Terapie manuală” ##{@service.id}", "s-a autentificat"], texts
    assert_includes today.css(".audit-entry-details li").map(&:text), "preț: 120 → 220"
    assert_includes today.css(".audit-entry-meta").map(&:text).join, "Chrome / Desktop · IP 10.0.0.7"
    update = today.css(".audit-entry--update").first
    assert_equal "POST /medical_services/terapie-manuala", update.at_css(".audit-entry-request").text
    assert_includes update.at_css(".audit-entry-meta").text, "din /dashboard/servicii-medicale"
    assert_equal "##{@service.id}", update.at_css(".audit-entry-id").text
    destroy = today.css(".audit-entry--destroy").first
    assert_equal ["nume: TAPE", "preț: 30"], destroy.css(".audit-entry-attrs li").map(&:text)
    assert_includes today.at_css(".audit-views summary").text, "a vizualizat 3 pagini"

    # Live search wiring (filtering itself runs in the browser)
    section = css_select("section[data-controller='journal-search']").first
    assert section, "report section drives the search controller"
    assert_equal 1, section.css("input[type=search][data-journal-search-target='input']").size
    assert_equal 2, section.css("[data-journal-search-target='day']").size
    assert_equal 4, section.css("[data-journal-search-target='entry']").size
    assert_equal 3, section.css("[data-journal-search-target='view']").size
    assert_equal 3, today.css(".audit-views-list li").size
    assert_includes days[1].css(".audit-entry-text").map { |e| e.text.squish }, "a creat anunțul de carieră „Medic” #5"
    assert_equal ["titlu: Medic"], days[1].css(".audit-entry--create .audit-entry-attrs li").map(&:text)
  end

  test "the period filter widens the window and keeps the user" do
    get "/dashboard/audit", params: { user: @admin.id, period: "90" }
    assert_response :success
    assert_includes css_select(".audit-entry-text").map { |e| e.text.squish }, "a modificat membrul echipei „Ioan” #1"
    active_pill = css_select(".audit-period-pill.active").first
    assert_equal "90 zile", active_pill.text.strip
    assert_includes active_pill["href"], "user=#{@admin.id}"
  end

  test "global search finds who changed a record, across users and all time" do
    get "/dashboard/audit", params: { q: "terapie" }
    assert_response :success
    assert_includes css_select("#audit-search-heading").first.text.squish, "1 rezultat pentru „terapie”"
    entry = css_select(".audit-search-results .audit-entry").first
    assert_includes entry.at_css(".audit-entry-user").text, "Ancuța"
    assert_includes entry.at_css(".audit-entry-text").text.squish, "a modificat serviciul medical „Terapie manuală”"
    assert_includes entry.css(".audit-entry-details li").map(&:text), "preț: 120 → 220"
    assert_empty css_select(".audit-summary"), "the per-user report is replaced by the results"

    get "/dashboard/audit", params: { q: "Ioan" }
    assert_includes css_select(".audit-search-results .audit-entry-text").map { |e| e.text.squish }, "admin@spinalcare.ro a modificat membrul echipei „Ioan” #1", "40-day-old edit is found: search ignores the period"
  end

  test "global search understands verbs, sections, IPs and emails, without diacritics" do
    get "/dashboard/audit", params: { q: "sters" }
    texts = css_select(".audit-search-results .audit-entry-text").map { |e| e.text.squish }
    assert_equal ["Ancuța a șters serviciul medical „TAPE” #999"], texts

    get "/dashboard/audit", params: { q: "ȘTERS tape" }
    assert_equal 1, css_select(".audit-search-results .audit-entry").size

    get "/dashboard/audit", params: { q: "cariere" }
    assert_includes css_select(".audit-search-results .audit-entry-text").map { |e| e.text.squish }, "Ancuța a creat anunțul de carieră „Medic” #5"

    get "/dashboard/audit", params: { q: "10.0.0.7" }
    assert_equal ["Ancuța s-a autentificat"], css_select(".audit-search-results .audit-entry-text").map { |e| e.text.squish }

    get "/dashboard/audit", params: { q: "editor@spinalcare.ro servicii" }
    assert_equal 5, css_select(".audit-search-results .audit-entry").size, "the editor's medical-service rows: update, delete and 3 views"
  end

  test "global search with no match says so and the form keeps the query" do
    get "/dashboard/audit", params: { q: "nimic-de-gasit" }
    assert_response :success
    assert_includes css_select("#audit-search-heading").first.text.squish, "0 rezultate"
    assert_includes response.body, "Niciun rezultat"
    assert_equal "nimic-de-gasit", css_select("#journal-global-q").first["value"]
    assert css_select("turbo-frame#audit-results").any?
  end

  test "an empty period shows an empty state" do
    AuditLog.delete_all
    get "/dashboard/audit"
    assert_response :success
    assert_includes response.body, "Nicio activitate înregistrată"
  end

  test "non-admins see the no-access page" do
    sign_in User.create!(email: "user@spinalcare.ro", password: "secret-password-1", admin: false)
    get "/dashboard/audit"
    assert_response :success
    assert_includes response.body, "Nu aveți drepturi"
    assert_not_includes response.body, "audit-user-card"
  end

  private

  def log(user, action, type, id, at:, data: nil, summary: nil, path: nil, method: nil, ua: nil, ip: nil, duration: nil, referer: nil)
    AuditLog.create!(user: user, action: action, auditable_type: type, auditable_id: id, created_at: at, updated_at: at,
                     change_data: data&.to_json, changes_summary: summary, request_path: path, request_method: method,
                     user_agent: ua, ip_address: ip, duration_ms: duration, referer: referer)
  end
end
