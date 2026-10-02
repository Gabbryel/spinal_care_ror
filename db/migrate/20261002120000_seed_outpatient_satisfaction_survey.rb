# A second questionnaire, for patients who come to consultations and
# therapies without being admitted, covering every active specialty except
# day hospitalisation (which has its own). Also gives each questionnaire the
# short label shown on /parerea-ta, where the patient picks the right one.
class SeedOutpatientSatisfactionSurvey < ActiveRecord::Migration[8.0]
  class Survey < ActiveRecord::Base
    self.table_name = "surveys"
  end

  class SurveyQuestion < ActiveRecord::Base
    self.table_name = "survey_questions"
  end

  class Specialty < ActiveRecord::Base
    self.table_name = "specialties"
  end

  FOUR = [["Foarte bine", 100], ["Bine", 67], ["Satisfăcător", 33], ["Nesatisfăcător", 0]].freeze

  def questions(specialties)
    [
      ["Despre dumneavoastră", "Vârsta", "choice", %w[<20 20-29 30-39 40-49 50-59 60-69 70+].map { |a| [a, nil] }, false, true],
      ["Despre dumneavoastră", "Sexul", "choice", [["Masculin", nil], ["Feminin", nil]], false, true],
      ["Despre dumneavoastră", "Este prima dată când veniți la Spinal Care?", "choice",
       [["Da, prima dată", nil], ["Nu, am mai fost", nil]], false, true],
      ["Vizita", "Pentru ce specialitate ați venit?", "choice",
       specialties.map { |name| [name, nil] } + [["Altă specialitate / nu știu", nil]], true, true],
      ["Vizita", "Consultația sau ședința a fost:", "choice",
       [["Cu bilet de trimitere (decontată de CAS)", nil], ["Cu plată", nil], ["Nu știu", nil]], false, true],
      ["Vizita", "Cum v-ați programat?", "choice",
       [["Telefonic", nil], ["Online, pe site", nil], ["La recepție", nil], ["Altfel", nil]], false, false],
      ["Programarea și primirea", "Cât de ușor v-a fost să obțineți o programare?", "rating",
       [["Foarte ușor", 100], ["Ușor", 67], ["Dificil", 33], ["Foarte dificil", 0]], true, false],
      ["Programarea și primirea", "Cum apreciați primirea la recepție (amabilitate, informații)?", "rating", FOUR, true, false],
      ["Programarea și primirea", "Cât ați așteptat peste ora programării?", "rating",
       [["Deloc sau sub 10 minute", 100], ["10–30 de minute", 67], ["30–60 de minute", 33], ["Peste o oră", 0]], true, false],
      ["Consultația sau terapia", "Cum apreciați atitudinea și comunicarea medicului sau a terapeutului?", "rating", FOUR, true, false],
      ["Consultația sau terapia", "Vi s-au explicat clar diagnosticul, tratamentul sau planul de recuperare?", "rating",
       [["Da, complet", 100], ["Parțial", 50], ["Nu", 0]], true, false],
      ["Consultația sau terapia", "Cum apreciați timpul acordat în cabinet sau în sala de terapie?", "rating", FOUR, true, false],
      ["Consultația sau terapia", "Cum apreciați calitatea serviciului medical primit?", "rating", FOUR, true, false],
      ["Clinica", "Curățenia și aspectul clinicii:", "rating", FOUR, true, false],
      ["Clinica", "Cum apreciați raportul dintre calitate și preț?", "rating", FOUR + [["Nu am plătit (CAS)", nil]], false, false],
      ["Clinica", "Ați primit documentele de care aveați nevoie (scrisoare medicală, rețetă, recomandări)?", "rating",
       [["Da", 100], ["Nu", 0], ["Nu a fost cazul", nil]], false, false],
      ["Impresie generală", "Impresia generală despre vizita la Spinal Care:", "rating",
       [["Foarte mulțumit", 100], ["Mulțumit", 50], ["Nemulțumit", 0]], true, false],
      ["Impresie generală", "Ați recomanda Spinal Care prietenilor sau familiei?", "rating",
       [["Sigur da", 100], ["Probabil da", 67], ["Probabil nu", 33], ["Sigur nu", 0]], true, false],
      ["Impresie generală", "Sugestii, observații, reclamații sau alte aspecte pe care doriți să ni le comunicați:", "text", [], false, false]
    ]
  end

  def up
    add_column :surveys, :audience, :string unless column_exists?(:surveys, :audience)
    Survey.reset_column_information
    Survey.where(slug: "satisfactie-pacienti-internati").update_all(audience: "Am fost internat (spitalizare de zi)")
    return if Survey.exists?(slug: "satisfactie-pacienti-ambulatoriu")

    specialties = Specialty.where(is_active: true).where.not(slug: "spitalizare-de-zi").order(:name).pluck(:name)
    survey = Survey.create!(
      title: "Chestionar de satisfacție pentru consultații și terapii",
      slug: "satisfactie-pacienti-ambulatoriu",
      audience: "Am venit la o consultație sau la terapie",
      active: true,
      intro: "Ați venit la o consultație, o investigație sau o ședință de terapie? Spuneți-ne cum a fost. " \
             "Răspunsurile rămân anonime: nu vă cerem numele și nu păstrăm adresa IP. Durează în jur de 3 minute.",
      thank_you: "Răspunsurile dumneavoastră ajung la conducerea clinicii și ne ajută să devenim mai buni."
    )
    questions(specialties).each_with_index do |(section, text, kind, options, required, segment), i|
      SurveyQuestion.create!(survey_id: survey.id, position: i + 1, section: section, text: text, kind: kind,
                             options: options.map { |label, score| { "label" => label, "score" => score } },
                             required: required, segment: segment, headline: text.start_with?("Impresia generală"))
    end
  end

  def down
    survey = Survey.find_by(slug: "satisfactie-pacienti-ambulatoriu")
    if survey
      SurveyQuestion.where(survey_id: survey.id).delete_all
      survey.destroy
    end
    remove_column :surveys, :audience
  end
end
