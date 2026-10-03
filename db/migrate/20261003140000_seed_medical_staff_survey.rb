# A third questionnaire: the patient picks one doctor, physiotherapist or
# nurse (read live from the team) and rates how that person treated them.
# The person question groups the interpretation, so each colleague gets
# their own index in the dashboard.
class SeedMedicalStaffSurvey < ActiveRecord::Migration[8.0]
  class Survey < ActiveRecord::Base
    self.table_name = "surveys"
  end

  class SurveyQuestion < ActiveRecord::Base
    self.table_name = "survey_questions"
  end

  FOUR = [["Foarte bine", 100], ["Bine", 67], ["Satisfăcător", 33], ["Nesatisfăcător", 0]].freeze

  QUESTIONS = [
    ["Despre cine este", "Pe cine doriți să evaluați?", "choice", "medical_staff", true, true],
    ["Despre cine este", "Este prima dată când ați fost la această persoană?", "choice",
     [["Da, prima dată", nil], ["Nu, am mai fost", nil]], false, true],
    ["Cum v-a tratat", "Amabilitatea și respectul cu care v-a tratat:", "rating", FOUR, true, false],
    ["Cum v-a tratat", "Cât de atent v-a ascultat:", "rating", FOUR, true, false],
    ["Cum v-a tratat", "Cât de clar v-a explicat ce aveți, tratamentul sau exercițiile și ce urmează:", "rating", FOUR, true, false],
    ["Cum v-a tratat", "Timpul pe care vi l-a acordat:", "rating", FOUR, true, false],
    ["Cum v-a tratat", "Grija pentru confortul și intimitatea dumneavoastră:", "rating", FOUR, true, false],
    ["Profesionalism", "Cum apreciați profesionalismul și competența sa?", "rating", FOUR, true, false],
    ["Profesionalism", "A fost punctual (ați fost primit la ora stabilită)?", "rating",
     [["Da", 100], ["Cu o mică întârziere", 50], ["Nu, am așteptat mult", 0]], true, false],
    ["Profesionalism", "V-ați simțit implicat în deciziile despre tratamentul dumneavoastră?", "rating",
     [["Da, complet", 100], ["Parțial", 50], ["Nu", 0], ["Nu a fost cazul", nil]], false, false],
    ["Pe scurt", "Cât de mulțumit sunteți, în general, de această persoană?", "rating",
     [["Foarte mulțumit", 100], ["Mulțumit", 50], ["Nemulțumit", 0]], true, false],
    ["Pe scurt", "Ați recomanda această persoană prietenilor sau familiei?", "rating",
     [["Sigur da", 100], ["Probabil da", 67], ["Probabil nu", 33], ["Sigur nu", 0]], true, false],
    ["Pe scurt", "Ce ați dori să-i transmiteți (mulțumiri, sugestii, nemulțumiri)?", "text", [], false, false]
  ].freeze

  def up
    return if Survey.exists?(slug: "evaluare-echipa-medicala")

    survey = Survey.create!(
      title: "Chestionar despre medicii, kinetoterapeuții și asistenții noștri",
      slug: "evaluare-echipa-medicala",
      audience: "Vreau să evaluez un medic, un kinetoterapeut sau o asistentă",
      active: true,
      intro: "Alegeți persoana din echipă la care ați fost și spuneți-ne cum v-a tratat. " \
             "Răspunsurile rămân anonime: nu vă cerem numele și nu păstrăm adresa IP. Durează în jur de 2 minute.",
      thank_you: "Răspunsurile dumneavoastră ajung la conducerea clinicii și ne ajută să devenim mai buni."
    )
    QUESTIONS.each_with_index do |(section, text, kind, options, required, segment), i|
      source = options if options.is_a?(String)
      SurveyQuestion.create!(survey_id: survey.id, position: i + 1, section: section, text: text, kind: kind,
                             options: source ? [] : options.map { |label, score| { "label" => label, "score" => score } },
                             options_source: source, required: required, segment: segment,
                             headline: text.start_with?("Cât de mulțumit sunteți"))
    end
  end

  def down
    survey = Survey.find_by(slug: "evaluare-echipa-medicala")
    return unless survey

    SurveyQuestion.where(survey_id: survey.id).delete_all
    survey.destroy
  end
end
