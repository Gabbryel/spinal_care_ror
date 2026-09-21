require "test_helper"

# Paid vs organic: the channel classifier (AnalyticsFilterHelper.channel_sql),
# the "Canal" filter applied to the whole analytics page, and the
# "Plătit vs. Organic" section with campaigns, names and spend.
class AnalyticsChannelsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  BROWSER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/128.0 Safari/537.36".freeze

  setup do
    Rails.cache.clear
    host! "www.spinalcare.ro"
    Rails.application.reload_routes_unless_loaded
    sign_in User.create!(email: "admin@spinalcare.ro", password: "secret-password-1", admin: true)
    @t = Time.zone.now.beginning_of_day - 1.day + 10.hours
    # 4 Google Ads visits (2 campaigns), 2 of them contact; 3 organic Google visits, 1 contacts;
    # 1 paid-by-UTM Facebook visit; 1 fbclid visit (social); 2 direct; 1 self-referral.
    4.times do |i|
      v = visit(landing: "https://www.spinalcare.ro/?gad_source=1&gad_campaignid=#{i < 3 ? 111 : 222}&gclid=abc#{i}", referrer: "www.google.com")
      view(v, "/"); contact(v, "call") if i < 2
    end
    3.times { |i| v = visit(referrer: "www.google.com"); view(v, "/"); contact(v, "booking") if i.zero? }
    visit(landing: "https://www.spinalcare.ro/?utm_source=facebook&utm_medium=paidsocial&utm_campaign=toamna", utm: { utm_source: "facebook", utm_medium: "paidsocial", utm_campaign: "toamna" })
    visit(landing: "https://www.spinalcare.ro/?fbclid=xyz")
    2.times { visit }
    visit(referrer: "spinalcare.ro")
  end

  test "the section splits visits by channel with contacts and rates" do
    get "/dashboard/analytics/channels", params: { period: "7" }
    assert_response :success

    groups = css_select(".bh-block")[0].css("tbody tr").map { |tr| tr.css("td").map { |td| td.text.strip } }
    assert_includes groups, ["Plătit", "5", "41.7%", "2", "0", "2", "2", "40.0"]
    assert_includes groups, ["Organic (căutare)", "3", "25.0%", "0", "1", "1", "1", "33.3"]
    assert_includes groups, ["Social", "1", "8.3%", "0", "0", "0", "0", "0.0"]
    assert_includes groups, ["Direct", "2", "16.7%", "0", "0", "0", "0", "0.0"]
    assert_includes groups, ["Alte site-uri + propriu", "1", "8.3%", "0", "0", "0", "0", "0.0"]
    assert_includes css_select(".bh-block")[0].text.squish, "Reclamele au adus 41.7% din vizite și 67% din contacte"

    channels = css_select(".bh-block")[1].css("tbody tr").map { |tr| tr.css("td").first.text.strip }
    assert_equal ["Google Ads", "Căutare organică", "Direct", "Alte reclame (UTM)", "Site propriu", "Social (Facebook, Instagram)"], channels

    campaigns = css_select(".bh-block")[2]
    rows = campaigns.css("tbody tr")
    assert_equal 2, rows.size
    assert_equal "nume pentru 111", rows[0].at_css("input[name=name]")["placeholder"], "unnamed campaign shows the naming form"
    assert_equal ["3", "2", "66.7"], rows[0].css("td.num").map { |td| td.text.strip }
  end

  test "the channel filter narrows the whole page, KPIs included" do
    get "/dashboard/analytics", params: { period: "7" }
    assert_response :success
    assert_equal "12", css_select(".kpi-card").first.at_css(".kpi-value").text.strip

    get "/dashboard/analytics", params: { period: "7", channel: "paid" }
    assert_equal "5", css_select(".kpi-card").first.at_css(".kpi-value").text.strip
    assert_equal "paid", css_select("select#channel option[selected]").first["value"]
    assert_includes css_select("turbo-frame#clicks").first["src"], "channel=paid"

    get "/dashboard/analytics/clicks", params: { period: "7", channel: "organic" }
    assert_equal "0", css_select(".clicks-kpis .kpi-card")[0].at_css(".kpi-value").text.strip, "organic visits made no calls"
    assert_equal "1", css_select(".clicks-kpis .kpi-card")[1].at_css(".kpi-value").text.strip, "one booking from organic"

    get "/dashboard/analytics/channels", params: { period: "7", channel: "paid" }
    assert_equal 5, css_select(".bh-block")[0].css("tbody tr").size, "the comparison ignores the channel filter"
  end

  test "admins can name a campaign and note monthly spend, giving a cost per contact" do
    post "/dashboard/analytics/campaign_name", params: { campaign_id: "111", name: "Brand Bacău", period: "7" }
    assert_redirected_to "/dashboard/analytics?period=7"
    post "/dashboard/analytics/ad_spend", params: { month: @t.strftime("%Y-%m"), amount: "1200", period: "7" }
    assert_redirected_to "/dashboard/analytics?period=7"

    get "/dashboard/analytics/channels", params: { period: "7" }
    assert_includes css_select(".bh-block")[2].css("tbody tr")[0].text, "Brand Bacău"
    spend = css_select(".bh-block")[3].text.squish
    assert_includes spend, "Cu 1,200 lei cheltuiți în lunile perioadei, un contact din reclame a costat 600 lei (240.0 lei pe vizită plătită)"

    post "/dashboard/analytics/ad_spend", params: { month: @t.strftime("%Y-%m"), amount: "900" }
    assert_equal 900, AdSpend.find_by(month: @t.to_date.beginning_of_month).amount, "same month is updated"
  end

  test "non-admins are refused" do
    sign_in User.create!(email: "user@spinalcare.ro", password: "secret-password-1", admin: false)
    get "/dashboard/analytics/channels", params: { period: "7" }
    assert_response :forbidden
    post "/dashboard/analytics/ad_spend", params: { month: "2026-09", amount: "1" }
    assert_response :forbidden
  end

  private

  def visit(landing: "https://www.spinalcare.ro/", referrer: nil, utm: {})
    @n = (@n || 0) + 1
    Ahoy::Visit.create!({ visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, started_at: @t + @n.minutes, user_agent: BROWSER,
                          landing_page: landing, referrer: referrer && "https://#{referrer}/", referring_domain: referrer,
                          device_type: "Mobile", country: "RO", city: "Bacău" }.merge(utm))
  end

  def view(visit, path)
    visit.events.create!(name: "$view", time: visit.started_at + 1, properties: { url: "https://www.spinalcare.ro#{path}", page: path })
  end

  def contact(visit, category)
    visit.events.create!(name: "$click", time: visit.started_at + 30,
                         properties: { category: category, destination: category == "call" ? "tel:0374554344" : "programari.spinalcare.ro (modal)",
                                       page: "/", text: category, element_type: "link", section: "main", timestamp: (visit.started_at + 30).iso8601(3) })
  end
end
