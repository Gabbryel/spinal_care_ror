require "test_helper"
require Rails.root.join("db/migrate/20261002090100_seed_inpatient_satisfaction_survey")
require Rails.root.join("db/migrate/20261002120000_seed_outpatient_satisfaction_survey")

# Patient questionnaires: the public form (anonymous, anti-spam, validation,
# scoring and alerts), the dashboard (management, answers, interpretation)
# and the "Spune-ne părerea ta" links across the site.
class SurveysTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  self.fixture_table_names = []

  setup do
    Rails.cache.clear
    host! "www.spinalcare.ro"
    Rails.application.reload_routes_unless_loaded
    @bullet_was_enabled = Bullet.enable?
    Bullet.enable = false
    ActiveRecord::Migration.suppress_messages { SeedInpatientSatisfactionSurvey.new.migrate(:up) }
    @survey = Survey.find_by!(slug: "satisfactie-pacienti-internati")
    @admin = User.create!(email: "admin@spinalcare.ro", password: "secret-password-1", admin: true)
  end

  teardown do
    Bullet.enable = @bullet_was_enabled
  end

  def question(start)
    @survey.questions.find { |q| q.text.start_with?(start) }
  end

  # Every required question answered with its first option ("Foarte bine",
  # "Da", ...), unless overridden by text prefix.
  def answers(overrides = {})
    @survey.questions.select { |q| q.required }.to_h { |q| [q.id.to_s, q.labels.first] }.tap do |h|
      overrides.each { |start, value| h[question(start).id.to_s] = value }
    end
  end

  def submit(answers_hash, wait: 10.seconds, extra: {})
    get "/chestionare/#{@survey.slug}"
    started = css_select("input[name=started]").first["value"]
    travel(wait) { post "/chestionare/#{@survey.slug}", params: { started: started, answers: answers_hash }.merge(extra) }
  end

  # ------------------------------------------------------------------ public

  test "the printed questionnaire is seeded with every question, in order, with the fixes" do
    assert_equal 26, @survey.questions.size
    assert_equal %w[<20 20-29 30-39 40-49 50-59 60-69 70+], question("Vârsta").labels
    assert question("Impresia generală").headline
    assert question("Pe ce specialitate").segment
    assert_equal "text", @survey.questions.last.kind
    assert_equal 6, @survey.sections.size
  end

  test "/parerea-ta opens the active questionnaire, which shows every question once" do
    get "/parerea-ta"
    assert_redirected_to "/chestionare/#{@survey.slug}"
    follow_redirect!
    assert_response :success
    assert_select "section.survey-step", 6
    assert_select ".survey-question", 26
    assert_select "input[name=website]", 1
    assert_select "meta[name=robots][content='noindex, follow']"
  end

  test "a complete response is saved anonymously, scored and thanked" do
    submit(answers)
    assert_redirected_to "/chestionare/#{@survey.slug}/multumim"

    response = SurveyResponse.last
    assert_equal 100.0, response.score
    assert_not response.alert
    assert_equal({ "label" => "Foarte bine", "score" => 100 }, response.answer_for(question("Cum apreciați modul")))
    assert_equal "web", response.source
    assert_not SurveyResponse.column_names.include?("ip"), "no IP is stored with the answers"
    follow_redirect!
    assert_select "h1", "Vă mulțumim!"
  end

  test "a missing required answer re-renders the form with the answers kept" do
    partial = answers.except(question("Impresia generală").id.to_s)
    submit(partial)
    assert_response :unprocessable_entity
    assert_select ".survey-error", /Impresia generală despre spitalul Spinal Care Dobreci/
    assert_select "input[name='answers[#{question('Cum apreciați modul').id}]'][value='Foarte bine'][checked]"
    assert_equal 0, SurveyResponse.count
  end

  test "bots are thanked but nothing is saved: hidden field, too fast, or no start token" do
    submit(answers, extra: { website: "http://spam.example" })
    assert_redirected_to "/chestionare/#{@survey.slug}/multumim"
    submit(answers, wait: 1.second)
    post "/chestionare/#{@survey.slug}", params: { answers: answers }
    assert_equal 0, SurveyResponse.count
  end

  test "an answer that is not one of the options is ignored" do
    submit(answers("Vârsta" => "150"))
    assert_nil SurveyResponse.last.answer_for(question("Vârsta"))
  end

  test "a dissatisfied response is flagged with its reasons and alerts by email when configured" do
    @survey.update!(alert_emails: "manager@example.com")
    bad = answers("Impresia generală" => "Nemulțumit", "Curățenia" => "Nesatisfăcător", "Cazarea" => "Nesatisfăcător")
    bad[question("Sugestii").id.to_s] = "Am așteptat foarte mult și camera era murdară."

    previous = ENV["POSTMARK_API_TOKEN"]
    ENV["POSTMARK_API_TOKEN"] = "test-token"
    assert_enqueued_emails(1) { submit(bad) }
    ENV["POSTMARK_API_TOKEN"] = previous

    response = SurveyResponse.last
    assert response.alert
    assert_includes response.alert_reasons, "Impresie generală: Nemulțumit"
    assert_includes response.alert_reasons, "3 răspunsuri la nivelul cel mai slab"
    assert_includes response.alert_reasons, "Comentariu cu o posibilă reclamație"

    mail = SurveyMailer.alert(response)
    assert_equal ["manager@example.com"], mail.to
    assert_includes mail.body.encoded, "/dashboard/chestionare/#{@survey.slug}/raspunsuri/#{response.id}"
  end

  test "no email is attempted while the mail service is not configured" do
    @survey.update!(alert_emails: "manager@example.com")
    previous = ENV.delete("POSTMARK_API_TOKEN")
    assert_no_enqueued_emails { submit(answers("Impresia generală" => "Nemulțumit")) }
    assert SurveyResponse.last.alert
  ensure
    ENV["POSTMARK_API_TOKEN"] = previous if previous
  end

  test "praise in the comment is not read as a complaint" do
    ok = answers
    ok[question("Sugestii").id.to_s] = "Curățenie impecabilă, recepția foarte amabilă. Mulțumesc!"
    submit(ok)
    assert_not SurveyResponse.last.alert
  end

  test "an inactive questionnaire is not reachable" do
    @survey.update!(active: false)
    get "/chestionare/#{@survey.slug}"
    assert_response :not_found
  end

  test "the feedback card appears on the home, info and day-hospital pages and in the menus" do
    Specialty.create!(name: "Spitalizare de zi", description: "<p>x</p>", is_day_hospitalize: true)
    Fact.create!(title: "Drepturile pacientului", content: "x") rescue nil
    get "/specialitati-medicale/spitalizare-de-zi"
    assert_select ".feedback-cta a[href='/chestionare/satisfactie-pacienti-internati']", 1
    get "/"
    assert_response :success
    assert_select ".feedback-cta a[href='/parerea-ta']", 1
    assert_select ".dropdown-menu a[href='/parerea-ta']", /Spune-ne părerea ta/
    assert_select "footer a[href='/parerea-ta']"
  end

  # ------------------------------------------------- consultations survey

  def seed_outpatient
    Specialty.create!(name: "Ortopedie", description: "<p>x</p>", is_active: true)
    Specialty.create!(name: "Terapie Schroth", description: "<p>x</p>", is_active: true)
    Specialty.create!(name: "Estetică medicală", description: "<p>x</p>", is_active: false)
    Specialty.create!(name: "Spitalizare de zi", description: "<p>x</p>", is_active: true, is_day_hospitalize: true)
    ActiveRecord::Migration.suppress_messages { SeedOutpatientSatisfactionSurvey.new.migrate(:up) }
    Survey.find_by!(slug: "satisfactie-pacienti-ambulatoriu")
  end

  test "the consultations questionnaire lists every active specialty except day hospitalisation" do
    outpatient = seed_outpatient
    specialty = outpatient.questions.find { |q| q.text.start_with?("Pentru ce specialitate") }
    assert_equal ["Ortopedie", "Terapie Schroth", "Altă specialitate / nu știu"], specialty.labels
    assert specialty.required && specialty.segment
    assert outpatient.headline_question.text.start_with?("Impresia generală despre vizita")
    assert_equal "Am fost internat (spitalizare de zi)", @survey.reload.audience
  end

  test "with two questionnaires /parerea-ta asks which one applies, consultations first" do
    seed_outpatient
    get "/parerea-ta"
    assert_response :success
    choices = css_select("a.survey-choice")
    assert_equal ["/chestionare/satisfactie-pacienti-ambulatoriu", "/chestionare/satisfactie-pacienti-internati"], choices.map { |a| a["href"] }
    assert_equal "Am venit la o consultație sau la terapie", choices.first.at_css("strong").text
  end

  test "a long option list is a dropdown, and a neutral option does not count in the score" do
    outpatient = seed_outpatient
    10.times { |i| Specialty.create!(name: "Specialitate #{i}", description: "<p>x</p>", is_active: true) }
    question = outpatient.questions.find { |q| q.text.start_with?("Pentru ce specialitate") }
    question.update!(options: question.options + (0..9).map { |i| { "label" => "Specialitate #{i}", "score" => nil } })

    get "/chestionare/#{outpatient.slug}"
    assert_select "select[name='answers[#{question.id}]'] option", question.labels.size + 1

    @survey = outpatient
    submit(answers("Cum apreciați raportul" => "Nu am plătit (CAS)"))
    response = SurveyResponse.last
    assert_equal "Nu am plătit (CAS)", response.answer_for(@survey.questions.find { |q| q.text.start_with?("Cum apreciați raportul") })["label"]
    assert_equal 100.0, response.score, "the CAS answer has no score and leaves the mean at 100"
  end

  test "the day-hospital page links straight to the inpatient questionnaire" do
    seed_outpatient
    get "/specialitati-medicale/spitalizare-de-zi"
    assert_select ".feedback-cta a[href='/chestionare/satisfactie-pacienti-internati']"
  end

  # --------------------------------------------------------------- dashboard

  test "only admins open the questionnaires; SEO specialists go to the analytics" do
    get "/dashboard/chestionare"
    assert_redirected_to "/users/sign_in"

    sign_in User.create!(email: "seo@example.com", password: "secret-password-1", seo_specialist: true)
    get "/dashboard/chestionare"
    assert_redirected_to "/dashboard/analytics"

    sign_out :user
    sign_in User.create!(email: "x@example.com", password: "secret-password-1")
    get "/dashboard/chestionare/#{@survey.slug}/interpretare"
    assert_response :forbidden
  end

  test "the interpretation reads the answers back in plain Romanian" do
    6.times { submit(answers) }
    2.times { submit(answers("Curățenia" => "Nesatisfăcător", "Ați fost informat despre drepturile" => "Nu", "Impresia generală" => "Mulțumit")) }
    2.times { submit(answers("Curățenia" => "Nesatisfăcător", "Impresia generală" => "Mulțumit")) }
    @survey.responses.alerts.update_all(status: "new")

    sign_in @admin
    get "/dashboard/chestionare/#{@survey.slug}/interpretare"
    assert_response :success

    text = css_select(".sv-findings").text.squish
    assert_includes text, "Cel mai slab evaluat „Curățenia în spital”: 60.0/100; 40.0% din răspunsuri sunt slabe."
    assert_includes text, "20.0% „Nu” la „Ați fost informat despre drepturile dumneavoastră ca pacient” (2 din 10)."
    assert_select ".sv-kpi-value", text: "10"
    assert_select "table.bh-table td", text: "Endocrinologie"
  end

  test "responses can be filtered to the negative ones, reviewed with a note and exported" do
    submit(answers)
    submit(answers("Impresia generală" => "Nemulțumit"))
    bad = SurveyResponse.alerts.last

    sign_in @admin
    get "/dashboard/chestionare/#{@survey.slug}/raspunsuri", params: { only: "alerts" }
    assert_select "table.sv-responses tbody tr", 1
    assert_select ".nav-alert-count", "1"

    patch "/dashboard/chestionare/#{@survey.slug}/raspunsuri/#{bad.id}", params: { survey_response: { status: "resolved", staff_note: "Am sunat pacientul." } }
    bad.reload
    assert_equal "resolved", bad.status
    assert_equal @admin, bad.reviewed_by
    assert_equal "Am sunat pacientul.", bad.staff_note

    get "/dashboard/chestionare/#{@survey.slug}/raspunsuri.csv"
    rows = CSV.parse(response.body, headers: true)
    assert_equal 2, rows.size
    assert_includes rows.headers, "Impresia generală despre spitalul Spinal Care Dobreci:"
    assert_equal ["Nemulțumit", "Foarte mulțumit"].sort, rows.map { |r| r["Impresia generală despre spitalul Spinal Care Dobreci:"] }.sort
  end

  test "admins add, edit, reorder and retire questions without rewriting old answers" do
    submit(answers)
    sign_in @admin
    cleaning = question("Curățenia")

    post "/dashboard/chestionare/#{@survey.slug}/intrebari", params: { survey_question: { section: "Extra", text: "Ați recomanda clinica?", kind: "rating", options_text: "Da=100\nNu=0", required: "1" } }
    added = @survey.questions.reload.last
    assert_equal "Ați recomanda clinica?", added.text
    assert_equal [{ "label" => "Da", "score" => 100 }, { "label" => "Nu", "score" => 0 }], added.options

    patch "/dashboard/chestionare/#{@survey.slug}/intrebari/#{cleaning.id}", params: { survey_question: { text: "Curățenia în saloane:" } }
    assert_equal "Curățenia în saloane:", cleaning.reload.text
    assert_equal "Foarte bine", SurveyResponse.last.answer_for(cleaning)["label"], "old answers keep their label"

    position = added.position
    patch "/dashboard/chestionare/#{@survey.slug}/intrebari/#{added.id}/move", params: { direction: "up" }
    assert_equal position - 1, added.reload.position

    delete "/dashboard/chestionare/#{@survey.slug}/intrebari/#{cleaning.id}"
    assert_not cleaning.reload.active, "answered questions are deactivated, not deleted"
    delete "/dashboard/chestionare/#{@survey.slug}/intrebari/#{added.id}"
    assert_not SurveyQuestion.exists?(added.id)

    post "/dashboard/chestionare/#{@survey.slug}/intrebari", params: { survey_question: { text: "Fără variante", kind: "rating", options_text: "" } }
    assert_match(/Întrebarea nu a fost adăugată/, flash[:alert])
  end

  test "a new questionnaire starts inactive with its own address" do
    sign_in @admin
    post "/dashboard/chestionare", params: { survey: { title: "Chestionar ambulatoriu" } }
    created = Survey.find_by!(title: "Chestionar ambulatoriu")
    assert_equal "chestionar-ambulatoriu", created.slug
    assert_not created.active
    assert_redirected_to "/dashboard/chestionare/chestionar-ambulatoriu/editare"
  end
end
