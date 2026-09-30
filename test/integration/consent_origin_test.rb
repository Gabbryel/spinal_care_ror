require "test_helper"

# Accepting cookies reloads the page, and that reload is where Ahoy opens the
# visit, so the request's own Referer is our page. gdpr_controller.js leaves
# the real referrer and landing page in the consent_origin cookie; the visit
# must use them, or every visitor who accepts counts as "own site".
class ConsentOriginTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @bullet_was_enabled = Bullet.enable?
    Bullet.enable = false
    host! "www.spinalcare.ro"
    cookies["cookie_consent"] = "all"
  end

  teardown do
    Bullet.enable = @bullet_was_enabled
  end

  BROWSER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36".freeze

  # Ahoy skips requests without a browser user agent as bots.
  def open_page(path, referer)
    get path, headers: { "Referer" => referer, "User-Agent" => BROWSER }
  end

  def origin(referrer:, landing_page:)
    cookies["consent_origin"] = { referrer: referrer, landing_page: landing_page }.to_json
  end

  test "the visit opened on the consent reload keeps the real referrer and landing page" do
    origin(referrer: "https://www.google.com/",
           landing_page: "https://www.spinalcare.ro/echipa?utm_source=newsletter&utm_campaign=toamna")

    open_page "/specialitati-medicale", "https://www.spinalcare.ro/specialitati-medicale"
    assert_response :success

    visit = Ahoy::Visit.last
    assert_equal "https://www.google.com/", visit.referrer
    assert_equal "www.google.com", visit.referring_domain
    assert_equal "https://www.spinalcare.ro/echipa?utm_source=newsletter&utm_campaign=toamna", visit.landing_page
    assert_equal "newsletter", visit.utm_source
    assert_equal "toamna", visit.utm_campaign
    assert cookies["consent_origin"].blank?, "the cookie is used once"
  end

  test "a visitor who typed the address is direct, not own site" do
    origin(referrer: "", landing_page: "https://www.spinalcare.ro/")

    open_page "/", "https://www.spinalcare.ro/"

    visit = Ahoy::Visit.last
    assert_nil visit.referrer
    assert_nil visit.referring_domain
  end

  test "a landing page on another host is ignored" do
    origin(referrer: "https://www.google.com/", landing_page: "https://evil.example/?utm_source=spam")

    open_page "/", "https://www.spinalcare.ro/"

    visit = Ahoy::Visit.last
    assert_equal "www.spinalcare.ro", visit.referring_domain
    assert_nil visit.utm_source
  end

  test "a malformed cookie falls back to the request" do
    cookies["consent_origin"] = "not json"

    open_page "/", "https://www.facebook.com/"
    assert_response :success

    assert_equal "www.facebook.com", Ahoy::Visit.last.referring_domain
  end

  test "without the cookie the visit uses the request as before" do
    open_page "/", "https://www.bing.com/"

    assert_equal "www.bing.com", Ahoy::Visit.last.referring_domain
  end
end
