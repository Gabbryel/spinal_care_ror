require "test_helper"

# A team member can practise several specialties. members.specialty_id is the
# primary one; member_specialties holds all of them, the primary included.
class MemberSpecialtiesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @bullet_was_enabled = Bullet.enable?
    Bullet.enable = false
    host! "www.spinalcare.ro"
    Rails.application.reload_routes_unless_loaded
    @medic = Profession.create!(name: "medic", has_specialty: true)
    @cardio = Specialty.create!(name: "Cardiologie")
    @interne = Specialty.create!(name: "Medicină internă")
    @recovery = Specialty.create!(name: "Recuperare medicală")
    @member = Member.create!(first_name: "Ștefan", last_name: "Moisei", profession: @medic, specialty: @cardio,
                             academic_title: "dr.", has_own_page: true, is_active: true)
  end

  teardown do
    Bullet.enable = @bullet_was_enabled
  end

  test "the primary specialty is always one of the member's specialties" do
    assert_equal [@cardio], @member.specialties.to_a

    @member.update!(specialty_ids: [@interne.id])
    assert_equal [@cardio, @interne], @member.reload.specialties.to_a
    assert_equal @cardio, @member.specialty
    assert_equal [@cardio, @interne], @member.ordered_specialties
  end

  test "without a primary, the first checked specialty becomes the primary" do
    member = Member.create!(first_name: "Ana", last_name: "Pop", profession: @medic,
                            specialty_ids: [@recovery.id, @interne.id])
    assert_equal @recovery, member.reload.specialty
    assert_equal [@interne, @recovery], member.specialties.to_a
  end

  test "a save that fails validation writes no specialty" do
    assert_not @member.update(first_name: "", specialty_ids: [@interne.id])
    assert_equal [@cardio], @member.reload.specialties.to_a
  end

  test "the admin form saves several specialties and the journal records the change once" do
    admin = User.create!(email: "admin@spinalcare.ro", password: "secret-password-1", admin: true)
    sign_in admin
    AuditLog.delete_all

    assert_difference -> { AuditLog.where(auditable_type: "Member", action: "update").count }, 1 do
      patch "/members/#{@member.slug}", params: { member: { specialty_id: @cardio.id, specialty_ids: ["", @interne.id, @recovery.id] } }
    end
    assert_response :redirect
    assert_equal [@cardio, @interne, @recovery], @member.reload.specialties.to_a

    log = AuditLog.where(auditable_type: "Member").last
    assert_equal ["Cardiologie", "Cardiologie, Medicină internă, Recuperare medicală"], log.parsed_changes["specialties"]

    patch "/members/#{@member.slug}", params: { member: { specialty_id: @cardio.id, specialty_ids: [""] } }
    assert_equal [@cardio], @member.reload.specialties.to_a, "unchecking everything keeps the primary"

    get "/dashboard/personal"
    assert_response :success
    form = "form#edit_member_#{@member.id}"
    assert_select "#{form} input[type=checkbox][name='member[specialty_ids][]'][value='#{@cardio.id}'][checked]"
    assert_select "#{form} input[type=checkbox][name='member[specialty_ids][]'][value='#{@interne.id}']:not([checked])"
  end

  test "the member appears on every specialty page and the team filter knows all of them" do
    @member.update!(specialty_ids: [@interne.id])

    [@cardio, @interne].each do |specialty|
      get "/specialitati-medicale/#{specialty.slug}"
      assert_response :success
      assert_select ".team-grid .modern-member-card[data-member-name=?]", "ștefan moisei"
    end

    get "/specialitati-medicale/#{@recovery.slug}"
    assert_select ".team-grid .modern-member-card[data-member-name=?]", "ștefan moisei", count: 0

    get "/echipa"
    card = css_select(".modern-member-card[data-member-name='ștefan moisei']").first
    assert_equal "#{@cardio.slug} #{@interne.slug}", card["data-specialty"]
    assert_equal ["Cardiologie", "Medicină internă"], card.css(".member-specialty").map { |a| a.text.squish }
    assert_select "#team-specialty-filter option[value=?]", @interne.slug
  end

  # The page used to concat the service doctors onto the live association,
  # which saved them into the specialty on every visit.
  test "viewing a specialty page does not attach the doctors of its services" do
    other = Member.create!(first_name: "Ioana", last_name: "Rusu", profession: @medic, specialty: @cardio, is_active: true)
    MedicalService.create!(name: "Consultație internă", price: 200, specialty: @interne, member: other)

    assert_no_difference -> { MemberSpecialty.count } do
      get "/specialitati-medicale/#{@interne.slug}"
    end
    assert_select ".team-grid .modern-member-card[data-member-name=?]", "ioana rusu"
    assert_equal [@cardio], other.reload.specialties.to_a
  end

  test "the profile lists every specialty in its badges and structured data" do
    @member.update!(specialty_ids: [@interne.id])

    get "/echipa/#{@member.slug}"
    assert_response :success
    assert_equal ["Cardiologie", "Medicină internă"], css_select(".hero-badge.specialty-badge").map { |b| b.text.squish }
    physician = css_select("script[type='application/ld+json']").map { |n| JSON.parse(n.text) }.find { |b| b["@type"] == "Physician" }
    assert_equal ["Cardiologie", "Medicină internă"], physician["medicalSpecialty"]
    assert_select "meta[name=description][content*=?]", "cardiologie și medicină internă"
  end

  test "deleting a specialty removes it from its members" do
    @member.update!(specialty_ids: [@interne.id])
    @interne.destroy!
    assert_equal [@cardio], @member.reload.specialties.to_a
  end
end
