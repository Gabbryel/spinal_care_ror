require "test_helper"

# SEO specialists: a user type that sees the dashboard's analytics section and
# nothing else. They read every analytics section, cannot use the forms that
# write (campaign names, ad spend, call tallies), and any other dashboard page
# sends them to the analytics.
class SeoSpecialistTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  PASSWORD = "secret-password-1".freeze

  setup do
    Rails.cache.clear
    host! "www.spinalcare.ro"
    Rails.application.reload_routes_unless_loaded
    @seo = User.create!(email: "seo@example.com", password: PASSWORD, seo_specialist: true)
    @admin = User.create!(email: "admin@spinalcare.ro", password: PASSWORD, admin: true, god_mode: true)
  end

  test "signing in takes an SEO specialist straight to the analytics" do
    post "/users/sign_in", params: { user: { email: @seo.email, password: PASSWORD } }
    assert_redirected_to "/dashboard/analytics"
  end

  test "every other dashboard page sends an SEO specialist to the analytics" do
    sign_in @seo
    %w[/dashboard /dashboard/users /dashboard/personal /dashboard/audit /dashboard/specialitati
       /dashboard/servicii-medicale /dashboard/cariere /dashboard/promotii /dashboard/consum-medicamente].each do |path|
      get path
      assert_redirected_to "/dashboard/analytics", "#{path} must not open for an SEO specialist"
    end
  end

  test "the analytics page opens with only the analytics in the menu" do
    sign_in @seo
    get "/dashboard/analytics"
    assert_response :success

    assert_select "turbo-frame#clicks"
    assert_select ".user-role", text: "SEO specialist"
    menu = css_select(".modern-admin-sidebar").first
    assert menu.at_css("a[href='/dashboard/analytics']")
    %w[/dashboard /dashboard/users /dashboard/personal /dashboard/audit].each do |path|
      assert_nil menu.at_css("a[href='#{path}']"), "#{path} is hidden from the menu"
    end
    assert_select "a.btn-back-new", count: 0
  end

  test "every analytics section renders for an SEO specialist" do
    sign_in @seo
    %w[daily_chart geography sources pages clicks audit behaviour channels hourly geo_sources bot_traffic].each do |section|
      get "/dashboard/analytics/#{section}", params: { period: "7" }
      assert_response :success, "section #{section}"
    end
  end

  test "an SEO specialist does not get the forms that write, and cannot post them" do
    sign_in @seo
    get "/dashboard/analytics/channels", params: { period: "7" }
    assert_select "form[action='/dashboard/analytics/ad_spend']", count: 0
    get "/dashboard/analytics/behaviour", params: { period: "7" }
    assert_select "form[action='/dashboard/analytics/call_tally']", count: 0

    post "/dashboard/analytics/ad_spend", params: { month: "2026-09", amount: "500" }
    assert_response :forbidden
    post "/dashboard/analytics/campaign_name", params: { campaign_id: "123", name: "x" }
    assert_response :forbidden
    post "/dashboard/analytics/call_tally", params: { date: "2026-09-30", calls: "3" }
    assert_response :forbidden
    get "/dashboard/analytics/debug"
    assert_includes [403, 404], response.status
    assert_equal 0, AdSpend.count
  end

  test "admins and SEO specialists are cached apart, so the forms never leak either way" do
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    # The channels section needs a visit in the period to render its blocks.
    visit = Ahoy::Visit.create!(visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, started_at: 1.hour.ago,
                                landing_page: "https://www.spinalcare.ro/?gclid=abc", referring_domain: "www.google.com")
    Ahoy::Event.create!(visit: visit, name: "$view", properties: { page: "/" }, time: 1.hour.ago)
    sign_in @admin
    get "/dashboard/analytics/channels", params: { period: "7" }
    assert_select "form[action='/dashboard/analytics/ad_spend']", count: 1

    sign_out @admin
    sign_in @seo
    get "/dashboard/analytics/channels", params: { period: "7" }
    assert_select "form[action='/dashboard/analytics/ad_spend']", count: 0
  ensure
    Rails.cache = previous
  end

  test "a signed-in user without a role still gets nothing" do
    sign_in User.create!(email: "someone@example.com", password: PASSWORD)
    get "/dashboard/analytics/clicks", params: { period: "7" }
    assert_response :forbidden
    get "/dashboard/analytics"
    assert_select "turbo-frame#clicks", count: 0
  end

  test "a god-mode admin grants and revokes the role from the users page" do
    sign_in @admin
    get "/dashboard/users"
    assert_select ".permission-badge", text: /SEO specialist/
    user = User.create!(email: "new@example.com", password: PASSWORD)

    patch "/users/#{user.id}", params: { user: { seo_specialist: "true" } }
    assert user.reload.seo_specialist?
    assert_equal "Utilizatorul este SEO specialist: vede doar secțiunea de analytics.", flash[:alert]

    patch "/users/#{user.id}", params: { user: { seo_specialist: "false" } }
    assert_not user.reload.seo_specialist?
  end

  test "an admin creates an SEO specialist from the users page" do
    sign_in @admin
    get "/dashboard/users"
    assert_select "form[action='/dashboard/users'] input[name='user[seo_specialist]'][type=checkbox]"

    post "/dashboard/users", params: { user: { email: "agentie@example.com", password: "parola-noua-1", seo_specialist: "1" } }
    assert_redirected_to "/dashboard/users"
    assert_equal "Contul agentie@example.com a fost creat (SEO specialist: vede doar secțiunea de analytics).", flash[:alert]
    created = User.find_by!(email: "agentie@example.com")
    assert created.seo_specialist?
    assert_not created.admin
    assert created.valid_password?("parola-noua-1")
  end

  test "creating an account cannot grant admin rights, and reports what is wrong" do
    sign_in @admin
    post "/dashboard/users", params: { user: { email: "x@example.com", password: "parola-noua-1", admin: "true", god_mode: "true" } }
    created = User.find_by!(email: "x@example.com")
    assert_not created.admin
    assert_not created.god_mode

    post "/dashboard/users", params: { user: { email: "x@example.com", password: "123" } }
    assert_redirected_to "/dashboard/users"
    assert_match(/Contul nu a fost creat/, flash[:alert])
    assert_equal 1, User.where(email: "x@example.com").count
  end

  test "only admins create accounts" do
    sign_in @seo
    post "/dashboard/users", params: { user: { email: "intrus@example.com", password: "parola-noua-1" } }
    assert_response :forbidden
    assert_not User.exists?(email: "intrus@example.com")
  end

  test "an admin who is also marked SEO specialist keeps the whole dashboard" do
    @admin.update!(seo_specialist: true)
    sign_in @admin
    get "/dashboard"
    assert_response :success
  end
end
