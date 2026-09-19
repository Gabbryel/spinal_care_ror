require "test_helper"

# The admin activity journal (/dashboard/audit): one card per user, the
# selected user's day-by-day report in plain Romanian, period filter.
class AuditReportTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

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
        data: { price: [120, 220], updated_at: ["2025-01-08", "2026-09-08"] }, summary: "Price: 120 → 220", path: "/medical_services/terapie-manuala", method: "POST")
    log(@editor, "destroy", "MedicalService", 999, at: @now - 50.minutes, data: { id: 999, name: "TAPE", price: 30 }, summary: "TAPE")
    log(@editor, "create", "JobPosting", 5, at: @now - 3.days, data: { title: "Medic", id: 5 })
    3.times { |i| log(@editor, "view", "MedicalService", 0, at: @now - 40.minutes + i.minutes, path: "/servicii-medicale", method: "GET", duration: 120 + i) }
    log(@admin, "update", "Member", 1, at: @now - 40.days, data: { first_name: ["Ion", "Ioan"] })
    log(@admin, "login", "User", @admin.id, at: @now - 10.days, data: { email: @admin.email })
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
    assert_equal ["a șters serviciul medical „TAPE”", "a modificat serviciul medical „Terapie manuală”", "s-a autentificat"], texts
    assert_includes today.css(".audit-entry-details li").map(&:text), "preț: 120 → 220"
    assert_includes today.css(".audit-entry-meta").map(&:text).join, "Chrome / Desktop · IP 10.0.0.7"
    assert_includes today.at_css(".audit-views summary").text, "a vizualizat 3 pagini"
    assert_equal 3, today.css(".audit-views-list li").size
    assert_includes days[1].css(".audit-entry-text").map { |e| e.text.squish }, "a creat anunțul de carieră „Medic”"
  end

  test "the period filter widens the window and keeps the user" do
    get "/dashboard/audit", params: { user: @admin.id, period: "90" }
    assert_response :success
    assert_includes css_select(".audit-entry-text").map { |e| e.text.squish }, "a modificat membrul echipei „Ioan”"
    active_pill = css_select(".audit-period-pill.active").first
    assert_equal "90 zile", active_pill.text.strip
    assert_includes active_pill["href"], "user=#{@admin.id}"
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

  def log(user, action, type, id, at:, data: nil, summary: nil, path: nil, method: nil, ua: nil, ip: nil, duration: nil)
    AuditLog.create!(user: user, action: action, auditable_type: type, auditable_id: id, created_at: at, updated_at: at,
                     change_data: data&.to_json, changes_summary: summary, request_path: path, request_method: method,
                     user_agent: ua, ip_address: ip, duration_ms: duration)
  end
end
