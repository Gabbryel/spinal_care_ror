require "test_helper"

# Request tests for the "Audit & Interpretare" analytics section
# (AdminController#analytics_audit, AnalyticsInsights).
class AnalyticsAuditTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  BROWSER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/128.0 Safari/537.36".freeze
  DEAD_END = "/specialitati-medicale/dexa".freeze

  setup do
    Rails.cache.clear
    host! "www.spinalcare.ro"
    Rails.application.reload_routes_unless_loaded
    sign_in User.create!(email: "admin@spinalcare.ro", password: "secret-password-1", admin: true)
    @now = Time.zone.now
  end

  test "audit and interpretation over a realistic period" do
    seed_period
    get "/dashboard/analytics/audit", params: { period: "7" }
    assert_response :success

    audit = findings(0)
    assert_includes audit["Urmărirea vizualizărilor funcționează"], "vizualizări de pagină în ultimele 24 de ore"
    assert_includes audit["Urmărirea click-urilor funcționează"], "click-uri"
    assert_includes audit["Trafic de boți identificat"], "10 din 70 vizite (14.3%)"
    assert_includes audit["Vizualizări duplicate"], "1 din"
    assert_includes audit["Trafic concentrat pe un singur IP"], "55 vizite"
    assert_includes audit["Vizite cu sursa „propriul site”"], "5 vizite (8.3%)"
    assert_includes audit["Acoperire geolocalizare"], "100.0% din vizite"
    # Bots are filtered out of the period, so every visit left has a $view.
    assert_nil audit["Vizite fără nicio pagină vizualizată"]
    assert_nil audit["Click-uri fără categorie"]

    insights = findings(1)
    assert_includes insights["Trafic"], "60 vizite de la 60 vizitatori unici"
    assert_includes insights["Trafic"], "↑ 100.0% față de perioada anterioară (30 vizite)"
    assert_includes insights["Rata de conversie"], "8 acțiuni de contact: 6 apeluri și 2 deschideri ale programării"
    assert_includes insights["Rata de conversie"], "13.3 la 100 de vizitatori unici (perioada anterioară: 3.3)"
    assert_includes insights["Paginile care duc cel mai des la contact"], "Homepage (13.1% din 61 vizualizări)"
    assert_includes insights["Pagini vizitate des, fără nicio acțiune de contact"], "#{DEAD_END} (35 vizualizări)"
    assert_includes insights["Surse de trafic"], "Google 50.0%"
    assert_includes insights["Surse de trafic"], "Cel mai bine convertesc vizitatorii din Google"
    assert_includes insights["Dispozitive"], "66.7% din vizite vin de pe mobil, 33.3% de pe desktop"
    assert_includes insights["Geografie"], "Bacău reprezintă 75.0%"
    assert_includes insights["Când contactează pacienții"], "se concentrează"
    assert_includes insights["Zile atipice"], "Cea mai bună zi"
  end

  test "views and clicks on a retired slug are merged into the current page" do
    cardio = Specialty.create!(name: "Cardiologie intervențională")
    SlugRedirect.record(cardio, "cardiologie-interven-ionala")
    old_path = "/specialitati-medicale/cardiologie-interven-ionala"
    new_path = "/specialitati-medicale/#{cardio.slug}"

    40.times do |i|
      v = visit(started_at: @now - (i % 7).days - 2.hours)
      view(v, i < 25 ? old_path : new_path, @now - (i % 7).days - 1.hour)
      click(v, "call", "tel:0374554344", i < 2 ? old_path : new_path, @now - (i % 7).days - 1.hour) if i < 4
    end

    get "/dashboard/analytics/audit", params: { period: "7" }
    assert_response :success
    insights = findings(1)
    assert_includes insights["Paginile care duc cel mai des la contact"], "#{new_path} (10.0% din 40 vizualizări)"
    assert_nil insights["Pagini vizitate des, fără nicio acțiune de contact"]
    assert_not_includes response.body, old_path
  end

  test "visits without page views are split by what they did record" do
    # 404s tracked server-side, silent visits, and one visit whose $view was
    # lost but whose click arrived (the only case that means broken tracking).
    3.times do |i|
      v = visit(started_at: @now - 1.hour)
      v.events.create!(name: "$not_found", time: @now - 1.hour + i.seconds,
                       properties: { path: "/pagina-stearsa-#{i}", referer: nil })
    end
    2.times { visit(started_at: @now - 2.hours) }
    click(visit(started_at: @now - 3.hours), "call", "tel:0374554344", "/", @now - 3.hours)
    v = visit(started_at: @now - 4.hours)
    view(v, "/", @now - 4.hours)

    get "/dashboard/analytics/audit", params: { period: "7" }
    assert_response :success
    body = findings(0)["Vizite fără nicio pagină vizualizată"]
    assert_includes body, "6 din 7 vizite (85.7%)"
    assert_includes body, "3 doar pagini inexistente (404)"
    assert_includes body, "2 fără niciun eveniment"
    assert_includes body, "1 cu click-uri dar fără vizualizare"
    assert_includes body, "404-uri urmărite pe server"
  end

  test "dead tracking is reported as a problem and an empty period says so" do
    old_visit = visit(started_at: @now - 20.days)
    old_visit.events.create!(name: "$view", time: @now - 20.days, properties: { url: "https://www.spinalcare.ro/", page: "/" })

    get "/dashboard/analytics/audit", params: { period: "7" }
    assert_response :success
    assert_includes findings(0)["Urmărirea vizualizărilor pare oprită"], "Nicio vizualizare de pagină înregistrată în ultimele 24 de ore"
    assert_select ".finding-bad", minimum: 1
    assert_includes findings(1)["Date insuficiente"], "Nu există vizite în perioada selectată"
  end

  test "non-admins are refused" do
    sign_in User.create!(email: "user@spinalcare.ro", password: "secret-password-1", admin: false)
    get "/dashboard/analytics/audit", params: { period: "7" }
    assert_response :forbidden
  end

  private

  # Column 0 = audit, column 1 = interpretation; returns { title => text + hint }.
  def findings(column)
    css_select(".audit-column")[column].css(".finding").each_with_object({}) do |f, h|
      h[f.at_css(".finding-title").text.strip] = f.at_css(".finding-body").text.squish
    end
  end

  # Current period (7 days): 60 real visits + 10 bot visits.
  #   - 55 visits from one IP (concentrated traffic), 5 from others
  #   - 30 Google referrals, 20 direct, 5 self-referrals, 5 Facebook
  #   - 40 Mobile, 20 Desktop; 45 Bacău, 15 Iași
  #   - every visit views "/", 35 visits also view DEAD_END; one visit has a duplicate view
  #   - 6 calls (5 Google, 1 Facebook) + 2 bookings (both Google), all on "/"
  # Previous period: 30 visits, 1 call.
  def seed_period
    60.times do |i|
      started = @now - (i % 7).days - 2.hours
      v = visit(started_at: started,
                ip: i < 55 ? "10.0.0.1" : "10.0.1.#{i}",
                referring_domain: i < 30 ? "www.google.com" : (i < 50 ? nil : (i < 55 ? "spinalcare.ro" : "m.facebook.com")),
                device_type: i < 40 ? "Mobile" : "Desktop",
                city: i < 45 ? "Bacău" : "Iași")
      view(v, "/", started + 1.second)
      view(v, DEAD_END, started + 10.seconds) if i < 35
      view(v, "/", started + 2.seconds) if i.zero? # duplicate within 3s
      click(v, "call", "tel:0374554344", "/", started + 20.seconds) if i < 5 || i == 56
      click(v, "booking", "programari.spinalcare.ro (modal)", "/", started + 25.seconds) if i.between?(5, 6)
    end
    10.times do |i|
      visit(started_at: @now - (i % 7).days - 3.hours, user_agent: "Mozilla/5.0 (compatible; Googlebot/2.1)", ip: "66.249.0.#{i}")
    end
    30.times do |i|
      v = visit(started_at: @now - 8.days - (i % 6).days)
      view(v, "/", @now - 8.days - (i % 6).days)
      click(v, "call", "tel:0374554344", "/", @now - 8.days) if i.zero?
    end
  end

  def visit(started_at:, user_agent: BROWSER, ip: "10.0.2.2", referring_domain: nil, device_type: "Mobile", city: "Bacău")
    Ahoy::Visit.create!(visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, started_at: started_at,
                        user_agent: user_agent, ip: ip, landing_page: "https://www.spinalcare.ro/",
                        referrer: referring_domain && "https://#{referring_domain}/", referring_domain: referring_domain,
                        device_type: device_type, country: "RO", city: city)
  end

  def view(visit, path, time)
    visit.events.create!(name: "$view", time: time, properties: { url: "https://www.spinalcare.ro#{path == '/' ? '/' : path}", page: path })
  end

  def click(visit, category, destination, page, time)
    visit.events.create!(name: "$click", time: time,
                         properties: { category: category, destination: destination, page: page, text: category,
                                       element_type: "link", section: "footer", timestamp: time.iso8601(3) })
  end
end
