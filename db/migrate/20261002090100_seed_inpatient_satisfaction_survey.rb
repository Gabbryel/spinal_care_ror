# The printed "Chestionar de evaluare a satisfacției pacienților internați"
# (2024) as the first online questionnaire. Same questions and order; the age
# groups no longer overlap ("<20" and "20-29") and the text has diacritics.
class SeedInpatientSatisfactionSurvey < ActiveRecord::Migration[8.0]
  class Survey < ActiveRecord::Base
    self.table_name = "surveys"
  end

  class SurveyQuestion < ActiveRecord::Base
    self.table_name = "survey_questions"
  end

  FOUR = [["Foarte bine", 100], ["Bine", 67], ["Satisfăcător", 33], ["Nesatisfăcător", 0]].freeze
  YES_NO = [["Da", 100], ["Nu", 0]].freeze
  ALWAYS = [["Da, întotdeauna", 100], ["Da, uneori", 50], ["Niciodată", 0]].freeze

  QUESTIONS = [
    ["Despre dumneavoastră", "Vârsta", "choice", %w[<20 20-29 30-39 40-49 50-59 60-69 70+].map { |a| [a, nil] }, false, true],
    ["Despre dumneavoastră", "Sexul", "choice", [["Masculin", nil], ["Feminin", nil]], false, true],
    ["Internarea", "Pe ce specialitate ați fost internat?", "choice",
     [["Endocrinologie", nil], ["Neurologie", nil], ["Medicină internă", nil], ["Recuperare, medicină fizică și balneologie", nil]], true, true],
    ["Internarea", "Cum apreciați modul în care ați fost primit și au fost ascultate solicitările dumneavoastră?", "rating", FOUR, true, false],
    ["Internarea", "La internare ați fost însoțit pe secție de:", "choice",
     [["Personalul spitalului", nil], ["Aparținători", nil], ["Am mers singur", nil]], true, false],
    ["Internarea", "Ați fost informat despre drepturile dumneavoastră ca pacient?", "rating", YES_NO, true, false],
    ["Internarea", "Ați fost informat despre diagnostic, tratament și regimul prescris de medic?", "rating", YES_NO, true, false],
    ["Personalul și condițiile", "Atitudinea și comunicarea cu personalul medical:", "rating", FOUR, true, false],
    ["Personalul și condițiile", "Cazarea, condițiile hoteliere și ambientul în spital:", "rating", FOUR, true, false],
    ["Personalul și condițiile", "Curățenia în spital:", "rating", FOUR, true, false],
    ["Personalul și condițiile", "Aspectul și curățenia lenjeriei și ale efectelor de spital:", "rating", FOUR, true, false],
    ["Personalul și condițiile", "Cum apreciați timpul acordat de medicul curant?", "rating", FOUR, true, false],
    ["Îngrijirea", "Cum apreciați calitatea îngrijirilor medicale acordate de medicul curant?", "rating", FOUR, true, false],
    ["Îngrijirea", "Cum apreciați calitatea îngrijirilor medicale acordate de asistenții medicali?", "rating", FOUR, true, false],
    ["Îngrijirea", "Cum apreciați calitatea activității infirmierelor?", "rating", FOUR, true, false],
    ["Îngrijirea", "Cum evaluați contactul cu personalul spitalului?", "rating",
     [["Cald", 100], ["Rece", 0], ["Agreabil", 100], ["Dezagreabil", 0]], true, false],
    ["Îngrijirea", "Ați fost mulțumit de îngrijirile acordate?", "rating", YES_NO, true, false],
    ["Medicamentele", "Ați fost instruit asupra modului în care trebuie să primiți medicamentele?", "rating", ALWAYS, true, false],
    ["Medicamentele", "Administrarea medicamentelor s-a făcut sub supravegherea asistentului medical?", "rating", ALWAYS, true, false],
    ["Medicamentele", "Ați primit medicamentele pentru o zi de tratament?", "rating", YES_NO, true, false],
    ["Medicamentele", "Medicamentele administrate în spital:", "choice",
     [["V-au fost date doar de spital", nil], ["Le-ați cumpărat", nil], ["Ambele variante", nil]], false, false],
    ["Medicamentele", "Cum achiziționați medicamentele?", "choice",
     [["Pe rețetă simplă eliberată de medicul de spital", nil], ["Pe rețetă gratuită eliberată de medicul de spital", nil]], false, false],
    ["Așteptare și impresie generală", "Cum evaluați timpul de așteptare pentru internare?", "rating", FOUR, true, false],
    ["Așteptare și impresie generală", "Cum evaluați timpul de așteptare pentru externare?", "rating", FOUR, true, false],
    ["Așteptare și impresie generală", "Impresia generală despre spitalul Spinal Care Dobreci:", "rating",
     [["Foarte mulțumit", 100], ["Mulțumit", 50], ["Nemulțumit", 0]], true, false],
    ["Așteptare și impresie generală", "Sugestii, observații, reclamații sau alte aspecte pe care doriți să ni le comunicați:", "text", [], false, false]
  ].freeze

  def up
    return if Survey.exists?(slug: "satisfactie-pacienti-internati")

    survey = Survey.create!(
      title: "Chestionar de evaluare a satisfacției pacienților internați",
      slug: "satisfactie-pacienti-internati",
      active: true,
      intro: "Acest chestionar ne ajută să îmbunătățim activitatea spitalului. Răspunsurile rămân anonime: " \
             "nu vă cerem numele și nu păstrăm adresa IP. Durează în jur de 3 minute. " \
             "Nu există răspunsuri corecte sau greșite.",
      thank_you: "Răspunsurile dumneavoastră ajung la conducerea clinicii și ne ajută să devenim mai buni."
    )
    QUESTIONS.each_with_index do |(section, text, kind, options, required, segment), i|
      SurveyQuestion.create!(survey_id: survey.id, position: i + 1, section: section, text: text, kind: kind,
                             options: options.map { |label, score| { "label" => label, "score" => score } },
                             required: required, segment: segment,
                             headline: text.start_with?("Impresia generală"))
    end
  end

  def down
    survey = Survey.find_by(slug: "satisfactie-pacienti-internati")
    return unless survey

    SurveyQuestion.where(survey_id: survey.id).delete_all
    survey.destroy
  end
end
