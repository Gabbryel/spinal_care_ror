require "test_helper"

# The public specialty page (/specialitati-medicale/:slug): contact actions
# in the first screen and right after the price list, prices before the
# specialists, and the actions wired so the click tracker counts them.
class SpecialtyPageTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @bullet_was_enabled = Bullet.enable?
    Bullet.enable = false
    host! "www.spinalcare.ro"
    medic = Profession.create!(name: "medic")
    @specialty = Specialty.create!(name: "Cardiologie intervențională", description: "<p>Proceduri minim invazive.</p>")
    MedicalService.create!(name: "Consultație", price: 250, specialty: @specialty)
    Member.create!(first_name: "Ștefan", last_name: "Moisei", profession: medic, specialty: @specialty,
                   has_own_page: true, selected: true, order: 1)
  end

  teardown do
    Bullet.enable = @bullet_was_enabled
  end

  test "contact actions appear under the hero and after the prices, before the specialists" do
    get "/specialitati-medicale/#{@specialty.slug}"
    assert_response :success

    ctas = css_select(".specialty-cta")
    assert_equal 2, ctas.size
    assert ctas[0].matches?(".specialty-cta--top")
    assert ctas[1].matches?(".specialty-cta--bottom")
    assert_includes ctas[0].at_css(".specialty-cta-title").text, "cardiologie intervențională"

    ctas.each do |cta|
      button = cta.at_css("button.specialty-cta-primary")
      assert_equal "#promoModal", button["data-bs-target"], "booking button opens the booking modal (tracked as booking)"
      phone = cta.at_css("a.specialty-cta-secondary")
      assert_equal "tel:0374554344", phone["href"], "phone is a tel: link (tracked as call)"
      assert_includes phone.text, "0374 554 344"
      assert_nil cta.at_css("svg:not([aria-hidden='true'])"), "icons are decorative"
    end

    body = response.body
    assert_operator body.index("specialty-cta--top"), :<, body.index("specialty-description")
    assert_operator body.index("Servicii Medicale"), :<, body.index("specialty-cta--bottom")
    assert_operator body.index("specialty-cta--bottom"), :<, body.index("Specialiști cardiologie")
    assert_nil body.index("btn-action !bg-orange-600"), "the old mid-page button is gone"
  end

  test "a specialty without services still gets both actions and no empty price section" do
    bare = Specialty.create!(name: "Nutriție")
    get "/specialitati-medicale/#{bare.slug}"
    assert_response :success
    assert_equal 2, css_select(".specialty-cta").size
    assert_not_includes response.body, "Servicii Medicale Nutriție"
  end
end
