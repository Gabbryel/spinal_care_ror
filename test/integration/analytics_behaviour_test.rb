require "test_helper"

# The "Parcurs & Comportament" analytics section (AdminController#analytics_behaviour,
# BehaviourAnalytics), the call-tally form, and the $not_found event.
class AnalyticsBehaviourTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  BROWSER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/128.0 Safari/537.36".freeze

  setup do
    Rails.cache.clear
    host! "www.spinalcare.ro"
    Rails.application.reload_routes_unless_loaded
    sign_in User.create!(email: "admin@spinalcare.ro", password: "secret-password-1", admin: true)
    @now = Time.zone.now
    seed
  end

  test "all fifteen blocks render with the seeded behaviour" do
    get "/dashboard/analytics/behaviour", params: { period: "7" }
    assert_response :success
    blocks = css_select(".behaviour-block")
    assert_equal 15, blocks.size
    text = ->(i) { blocks[i].text.squish }

    paths = blocks[0].css("tbody tr").map { |tr| [tr.at_css(".behaviour-path").text.strip, tr.at_css(".page-count").text.strip] }
    assert_includes paths, ["Homepage → /specialitati-medicale/ortopedie → /echipa/ion-popescu", "1"]
    assert_includes text.(1), "decid sub un minut"
    assert_includes text.(1), "Pagini văzute înainte de contact:"
    assert_includes text.(2), "/specialitati-medicale/ortopedie"
    assert_includes text.(2), "Programare"          # first click of the Google lander
    assert_includes text.(3), "din vizite sunt reveniri (1 din 10)"
    assert_includes text.(4), "contact cu / fără profil văzut"
    assert_includes text.(4), "ion-popescu 1"
    assert_includes text.(5), "vizite cu 5+ click-uri de navigare și niciun contact"
    assert_includes text.(5), "(10.0%)" # the one looping visit out of ten
    assert_includes text.(6), "Mobile"
    assert_includes text.(6), "Desktop"
    assert_includes text.(7), "Vârfuri:"
    assert_equal ["facebook / cpc / toamna", "1", "1"], blocks[8].css("tbody tr td").map { |td| td.text.strip }
    assert_equal ["/specialitati-medicale/ortopedie", "5", "42 s", "75%", "80.0%"], blocks[9].css("tbody tr td").map { |td| td.text.strip }
    assert_includes text.(10), "deschideri ale ferestrei de programări"
    assert_equal ["2", "1", "1"], blocks[10].css(".behaviour-stats strong").map(&:text), "opens, started, completed"
    assert_includes text.(11), "click-uri devin apeluri reale"
    assert_equal ["popesc", "2", "1 ✕"], blocks[12].css("tbody tr td").map { |td| td.text.strip }
    assert_includes text.(13), "Ortopedie 2"
    assert_includes text.(13), "Consultație 1"
    assert_equal ["/pagina-veche", "2", "spinalcare.ro/servicii-medicale"], blocks[14].css("tbody tr td").map { |td| td.text.strip }
  end

  test "reception can note received calls and the ratio appears" do
    day = (@now - 1.day).to_date # the seeded clicks happened yesterday: 3 tel: clicks
    post "/dashboard/analytics/call_tally", params: { date: day.to_s, calls: 6, note: "test", period: "7" }
    assert_redirected_to "/dashboard/analytics?period=7"
    assert_equal 6, CallTally.find_by(date: day).calls

    get "/dashboard/analytics/behaviour", params: { period: "7" }
    tally = css_select(".behaviour-block")[11].text.squish
    assert_includes tally, "un click pe telefon a însemnat în medie 2.0 apeluri primite (1 zile cu date)"

    post "/dashboard/analytics/call_tally", params: { date: day.to_s, calls: 5 }
    assert_equal 5, CallTally.find_by(date: day).calls, "same day is updated, not duplicated"
  end

  test "a real visitor's 404 is recorded with its referer" do
    sign_out :user
    assert_difference -> { Ahoy::Event.where(name: "$not_found").count }, 1 do
      get "/pagina-inexistenta-xyz", headers: { "User-Agent" => BROWSER, "Referer" => "https://www.spinalcare.ro/echipa" }
    end
    assert_response :not_found
    event = Ahoy::Event.where(name: "$not_found").last
    assert_equal "/pagina-inexistenta-xyz", event.properties["path"]
    assert_equal "https://www.spinalcare.ro/echipa", event.properties["referer"]

    assert_no_difference -> { Ahoy::Event.where(name: "$not_found").count } do
      get "/wp-login.php", headers: { "User-Agent" => BROWSER }
    end
  end

  test "non-admins are refused" do
    sign_in User.create!(email: "user@spinalcare.ro", password: "secret-password-1", admin: false)
    get "/dashboard/analytics/behaviour", params: { period: "7" }
    assert_response :forbidden
    post "/dashboard/analytics/call_tally", params: { date: @now.to_date.to_s, calls: 3 }
    assert_response :forbidden
  end

  private

  # Four visits in the period:
  #  A (mobile, Google, returning): / -> ortopedie -> profile ion-popescu -> call, 90 s in, plus a booking open and a completed booking message
  #  B (desktop, Google, first): ortopedie landing, first click "Programare" (booking), 30 s
  #  C (desktop, direct, first): 5 nav clicks, no contact (looping), last click in footer, searched the team twice
  #  E (mobile, direct): price list, tapped "Sună pentru preț" on Consultație
  #  D (mobile, facebook/cpc/toamna, first): / -> call
  # plus an older visit of A's visitor (for "returning"), 5 $leave rows on ortopedie, section views, labelled call, 404s.
  def seed
    a_visitor = SecureRandom.uuid
    visit(started_at: @now - 20.days, visitor: a_visitor) # earlier visit of the same person
    t = @now - 1.day
    a = visit(started_at: t, visitor: a_visitor, device: "Mobile", referrer: "www.google.com", landing: "https://www.spinalcare.ro/")
    view(a, "/", t); view(a, "/specialitati-medicale/ortopedie", t + 20); view(a, "/echipa/ion-popescu", t + 60)
    click(a, "call", "tel:0374554344", "/echipa/ion-popescu", t + 90, section: "main")
    click(a, "booking", "programari.spinalcare.ro (modal)", "/echipa/ion-popescu", t + 100, section: "main")
    event(a, "$booking", { step: "started", page: "/echipa/ion-popescu" }, t + 110)
    event(a, "$booking", { step: "completed", page: "/echipa/ion-popescu" }, t + 200)

    b = visit(started_at: t + 1.hour, device: "Desktop", referrer: "www.google.com", landing: "https://www.spinalcare.ro/specialitati-medicale/ortopedie")
    view(b, "/specialitati-medicale/ortopedie", t + 1.hour)
    click(b, "booking", "programari.spinalcare.ro (modal)", "/specialitati-medicale/ortopedie", t + 1.hour + 30, text: "Programare", section: "nav")

    c = visit(started_at: t + 2.hours, device: "Desktop", landing: "https://www.spinalcare.ro/")
    view(c, "/", t + 2.hours)
    5.times { |i| click(c, "nav", "https://www.spinalcare.ro/echipa", "/", t + 2.hours + i * 10, section: i == 4 ? "footer" : "nav") }
    event(c, "$search", { page: "/echipa", term: "popesc", results: 1 }, t + 2.hours + 60)
    event(c, "$search", { page: "/echipa", term: "popesc", results: 0 }, t + 2.hours + 70)
    event(c, "$section_view", { page: "/servicii-medicale", section: "Ortopedie" }, t + 2.hours + 80)
    event(c, "$section_view", { page: "/servicii-medicale", section: "Ortopedie" }, t + 2.hours + 81) # same section again counts as a view row
    e = visit(started_at: t + 2.hours + 30.minutes, device: "Mobile", landing: "https://www.spinalcare.ro/servicii-medicale")
    view(e, "/servicii-medicale", t + 2.hours + 30.minutes)
    click(e, "call", "tel:0374554344", "/servicii-medicale", t + 2.hours + 31.minutes, text: "Sună pentru preț", label: "Consultație", section: "main")

    d = visit(started_at: t + 3.hours, device: "Mobile", referrer: "m.facebook.com", landing: "https://www.spinalcare.ro/?utm_source=facebook",
              utm: { utm_source: "facebook", utm_medium: "cpc", utm_campaign: "toamna" })
    view(d, "/", t + 3.hours); click(d, "call", "tel:0374554344", "/", t + 3.hours + 20, section: "header")

    # engagement on the ortopedie page: 5 leave rows, avg 42 s, avg depth 75, 4 of 5 saw the CTA
    [[30, 50, true], [40, 75, true], [50, 100, true], [45, 75, true], [45, 75, false]].each_with_index do |(sec, depth, seen), i|
      v = visit(started_at: t + 4.hours + i.minutes, device: "Mobile")
      event(v, "$leave", { page: "/specialitati-medicale/ortopedie", seconds: sec, depth: depth, cta_present: true, cta_seen: seen }, t + 4.hours + i.minutes + 50)
    end

    # dead links
    2.times { |i| event(a, "$not_found", { path: "/pagina-veche", referer: "https://www.spinalcare.ro/servicii-medicale" }, t + 5.hours + i) }
  end

  def visit(started_at:, visitor: SecureRandom.uuid, device: "Mobile", referrer: nil, landing: "https://www.spinalcare.ro/", utm: {})
    Ahoy::Visit.create!({ visit_token: SecureRandom.uuid, visitor_token: visitor, started_at: started_at, user_agent: BROWSER,
                          landing_page: landing, referrer: referrer && "https://#{referrer}/", referring_domain: referrer,
                          device_type: device, country: "RO", city: "Bacău" }.merge(utm))
  end

  def view(visit, path, time)
    visit.events.create!(name: "$view", time: time, properties: { url: "https://www.spinalcare.ro#{path == '/' ? '/' : path}", page: path })
  end

  def click(visit, category, destination, page, time, text: category, section: "footer", label: nil)
    visit.events.create!(name: "$click", time: time,
                         properties: { category: category, destination: destination, page: page, text: text, label: label,
                                       element_type: "link", section: section, timestamp: time.iso8601(3) }.compact)
  end

  def event(visit, name, properties, time)
    visit.events.create!(name: name, time: time, properties: properties)
  end
end
