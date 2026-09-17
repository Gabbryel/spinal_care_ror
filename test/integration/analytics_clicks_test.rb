require "test_helper"

# Request tests for the "Click-uri și Conversii" analytics section
# (AdminController#analytics_clicks): conversion tiles with previous-period
# trend, top destinations, the per-page breakdown and the bot filter.
class AnalyticsClicksTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  BROWSER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/128.0 Safari/537.36".freeze

  setup do
    Rails.cache.clear
    host! "www.spinalcare.ro"
    # Routes load lazily in the test env; Devise's sign_in needs the mapping.
    Rails.application.reload_routes_unless_loaded
    sign_in User.create!(email: "admin@spinalcare.ro", password: "secret-password-1", admin: true)

    @now = Time.zone.now
    # Current period (last 7 days): two real visitors and one bot.
    @visitor_a = visit(started_at: @now - 1.day, visitor: "a")
    @visitor_b = visit(started_at: @now - 2.days, visitor: "b")
    @bot = visit(started_at: @now - 1.day, visitor: "bot", user_agent: "Mozilla/5.0 (compatible; Googlebot/2.1)")
    # Previous period (7 to 14 days ago): one call.
    @old = visit(started_at: @now - 10.days, visitor: "old")

    click(@visitor_a, "call", "tel:0374554344", page: "/", text: "0374 554 344", time: @now - 1.day)
    click(@visitor_a, "call", "tel:0374554344", page: "/echipa", text: "0374 554 344", time: @now - 1.day + 1.hour)
    click(@visitor_b, "booking", "programari.spinalcare.ro (modal)", page: "/", text: "Programare", time: @now - 2.days)
    click(@visitor_b, "nav", "https://www.spinalcare.ro/servicii-medicale", page: "/", text: "Prețuri", time: @now - 2.days + 1.minute)
    click(@visitor_b, "social", "https://www.facebook.com/SpinalCareBacau", page: "/echipa", text: "", time: @now - 2.days + 2.minutes)
    click(@bot, "call", "tel:0374554344", page: "/", text: "0374 554 344", time: @now - 1.day)
    click(@old, "call", "tel:0374554344", page: "/", text: "0374 554 344", time: @now - 10.days)
  end

  test "conversion tiles count categorised clicks from real visitors, with trend and rate" do
    get "/dashboard/analytics/clicks", params: { period: "7" }
    assert_response :success

    tiles = css_select(".clicks-kpis .kpi-card")
    assert_equal 4, tiles.size

    calls = tiles[0]
    assert_includes calls.text, "Apeluri telefonice"
    assert_equal "2", calls.at_css(".kpi-value").text.strip, "bot click must be filtered out"
    assert_includes calls.at_css(".kpi-trend").text, "100.0%", "2 calls vs 1 in the previous period"
    assert_includes calls.at_css(".kpi-subvalue").text, "100.0 la 100 de vizitatori unici"

    bookings = tiles[1]
    assert_includes bookings.text, "Programări"
    assert_equal "1", bookings.at_css(".kpi-value").text.strip

    assert_includes css_select(".summary-value").first.text, "5", "total clicks (nav and social included)"
  end

  test "top destinations are labelled by category with a readable destination" do
    get "/dashboard/analytics/clicks", params: { period: "7" }

    rows = css_select(".pages-table-container").first.css("tbody tr")
    assert_equal "0374554344", rows.first.at_css(".page-path").text.strip
    assert_equal "Apel telefonic", rows.first.at_css(".click-badge").text.strip
    assert_equal "2", rows.first.at_css(".page-count").text.strip

    labels = rows.map { |r| r.at_css(".page-path").text.strip }
    assert_includes labels, "/servicii-medicale", "site links are shown as paths"
    assert_includes labels, "facebook.com/SpinalCareBacau"
  end

  test "per-page breakdown defaults to the busiest page and follows the page param" do
    get "/dashboard/analytics/clicks", params: { period: "7" }
    select = css_select("select#page").first
    assert_equal "/", select.at_css("option[selected]")["value"]
    assert_includes select.at_css("option[selected]").text, "Homepage (3)"
    page_rows = css_select(".pages-table-container")[1].css("tbody tr")
    assert_equal 3, page_rows.size

    get "/dashboard/analytics/clicks", params: { period: "7", page: "/echipa" }
    assert_response :success
    page_rows = css_select(".pages-table-container")[1].css("tbody tr")
    assert_equal 2, page_rows.size
    assert_includes page_rows.map(&:text).join, "0374 554 344"
    assert_includes page_rows.map(&:text).join, "Social media"
  end

  test "bots can be included and the section is cached per filter set" do
    get "/dashboard/analytics/clicks", params: { period: "7", filter_bots: "false" }
    assert_equal "3", css_select(".clicks-kpis .kpi-card").first.at_css(".kpi-value").text.strip

    get "/dashboard/analytics/clicks", params: { period: "7" }
    assert_equal "2", css_select(".clicks-kpis .kpi-card").first.at_css(".kpi-value").text.strip
  end

  test "empty period renders the empty state" do
    get "/dashboard/analytics/clicks", params: { period: "custom", custom_start_date: (@now - 60.days).to_date.to_s, custom_end_date: (@now - 50.days).to_date.to_s }
    assert_response :success
    assert_includes response.body, "Nu există click-uri înregistrate"
  end

  test "non-admins are refused, for this and the other lazy sections" do
    sign_in User.create!(email: "user@spinalcare.ro", password: "secret-password-1", admin: false)
    %w[clicks pages geography].each do |section|
      get "/dashboard/analytics/#{section}", params: { period: "7" }
      assert_response :forbidden, section
      assert_not_includes response.body, "kpi-value"
    end
  end

  # Turbo parses each response with DOMParser (scripting disabled), where an
  # <img> or <iframe> inside <head> implicitly opens <body>. Everything after
  # it is then treated as body content and re-executed on every Turbo visit,
  # which doubled $view events. Nokogiri::HTML5 parses the same way.
  test "tracking scripts stay inside head under an HTML5 parser" do
    get "/"
    assert_response :success
    doc = Nokogiri::HTML5(response.body)
    assert_empty doc.css("head img, head iframe"), "head must not contain img/iframe (noscript pixels go in body)"
    assert doc.at_css("head script[src*='ahoy']"), "ahoy.js must be in head"
    ahoy_config = doc.css("head script:not([src])").find { |s| s.text.include?("ahoy.configure") }
    assert ahoy_config, "ahoy config script must be in head"
    assert_includes ahoy_config.text, "ahoyViewTrackingBound"
    assert_equal 1, response.body.scan('addEventListener("turbo:load"').size, "one turbo:load view listener"
  end

  private

  def visit(started_at:, visitor:, user_agent: BROWSER)
    Ahoy::Visit.create!(visit_token: SecureRandom.uuid, visitor_token: "visitor-#{visitor}-#{SecureRandom.hex(3)}",
                        started_at: started_at, user_agent: user_agent, landing_page: "https://www.spinalcare.ro/", country: "Romania")
  end

  def click(visit, category, destination, page:, text:, time:)
    visit.events.create!(name: "$click", time: time,
                         properties: { category: category, destination: destination, page: page, text: text,
                                       element_type: "link", section: "footer", timestamp: time.iso8601(3) })
  end
end
