require "test_helper"

# Contact actions on the home page (in the hero and after the Schroth section)
# and on the team page (under the hero and after the last profession), wired
# so the click tracker counts them as a booking and a call.
class HomeTeamCtaTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @bullet_was_enabled = Bullet.enable?
    Bullet.enable = false
    host! "www.spinalcare.ro"
    medic = Profession.create!(name: "medic")
    specialty = Specialty.create!(name: "Ortopedie", description: "<p>Articulații.</p>")
    Member.create!(first_name: "Ștefan", last_name: "Moisei", profession: medic, specialty: specialty,
                   academic_title: "dr.", has_own_page: true, selected: true, is_active: true, order: 1)
  end

  teardown do
    Bullet.enable = @bullet_was_enabled
  end

  test "the home page has contact actions in the hero and a contact card after Schroth" do
    get "/"
    assert_response :success

    hero = css_select(".modern-landing-hero .hero-cta")
    assert_equal 1, hero.size
    assert hero.first.at_css("button.specialty-cta-primary[data-bs-target='#promoModal']")
    assert hero.first.at_css("a.specialty-cta-secondary[href='tel:0374554344']")

    cards = css_select(".home-contact-cta .specialty-cta--bottom")
    assert_equal 1, cards.size
    assert_equal "Programează-te acum", cards.first.at_css(".specialty-cta-title").text.strip

    body = response.body
    assert_operator body.index("hero-cta"), :<, body.index("hero-stats-container")
    assert_operator body.index("specialisti schroth"), :<, body.index("home-contact-cta")
  end

  test "the promotions page has a contact card under the header and after the offers" do
    PromoPackage.create!(name: "Pachet recuperare coloană", valid_until: Date.current + 20.days)
    get "/promotii"
    assert_response :success

    ctas = css_select(".promo-contact-cta .specialty-cta")
    assert_equal 2, ctas.size
    assert ctas[0].matches?(".specialty-cta--top")
    assert_equal "Programează-te pentru unul dintre pachetele promoționale", ctas[0].at_css(".specialty-cta-title").text.strip
    assert ctas[1].matches?(".specialty-cta--bottom")
    assert_equal 2, css_select(".specialty-cta button[data-bs-target='#promoModal']").size
    assert_equal 2, css_select(".specialty-cta a[href='tel:0374554344']").size

    body = response.body
    assert_operator body.index("specialty-cta--top"), :<, body.index("Pachet recuperare coloană")
    assert_operator body.index("Pachet recuperare coloană"), :<, body.index("specialty-cta--bottom")
  end

  test "without offers the promotions page still offers the contact card once" do
    get "/promotii"
    assert_response :success
    assert_equal 1, css_select(".promo-contact-cta .specialty-cta").size
  end

  test "the team page has a contact card under the hero and at the end of every section" do
    Member.create!(first_name: "Lucian", last_name: "Dobreci", profession: Profession.find_by!(name: "medic"),
                   founder: true, is_active: true)
    get "/echipa"
    assert_response :success

    top = css_select(".specialty-cta--top")
    assert_equal 1, top.size
    assert_equal "Programează o consultație cu unul dintre specialiștii noștri",
                 top.first.at_css(".specialty-cta-title").text.strip

    sections = css_select(".founder-section, .profession-section")
    assert_equal 2, sections.size
    sections.each do |section|
      cards = section.css(".specialty-cta--bottom")
      assert_equal 1, cards.size, "each section ends with its own card"
      assert_equal "Programează-te acum", cards.first.at_css(".specialty-cta-title").text.strip
      assert_nil cards.first.next_element, "the card is the last thing in the section"
    end
    assert_equal 3, css_select(".specialty-cta button[data-bs-target='#promoModal']").size
    assert_equal 3, css_select(".specialty-cta a[href='tel:0374554344']").size

    title_ids = css_select(".specialty-cta-title").map { |t| t["id"] }
    assert_equal title_ids.uniq, title_ids, "every card has its own title id"
    css_select(".specialty-cta").each do |cta|
      assert_equal 1, css_select("##{cta['aria-labelledby']}").size
    end

    body = response.body
    assert_operator body.index("team-hero"), :<, body.index("specialty-cta--top")
    assert_operator body.index("specialty-cta--top"), :<, body.index("team-filters")
  end
end
