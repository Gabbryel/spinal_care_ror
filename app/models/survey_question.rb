# One question of a survey. `options` is an ordered list of
# { "label" => ..., "score" => 0..100 or nil }; a nil score marks an option
# that describes rather than rates (specialty, age, how medicines were paid).
class SurveyQuestion < ApplicationRecord
  include Auditable

  KINDS = { "rating" => "Evaluare (cu scor)", "choice" => "Alegere (fără scor)", "text" => "Text liber" }.freeze

  # Option lists read from the database every time a form opens, so a new or
  # renamed specialty or colleague shows up without anyone editing the
  # questionnaire. Each source ends with its own "other" option.
  OTHER = "Altă specialitate / nu știu".freeze
  OTHER_STAFF = "Altcineva din echipă / nu știu numele".freeze
  # Clinical professions a patient deals with directly: doctors,
  # physiotherapists and nurses (not reception, management or orderlies).
  MEDICAL_STAFF_PROFESSIONS = %w[medic fiziokinetoterapeut asistent-medical-generalist asistent-medical-bfkt asistent-medical-de-radiologie].freeze
  SOURCES = {
    "specialties" => {
      label: "Specialitățile active ale clinicii (fără spitalizarea de zi)",
      names: -> { Specialty.where(is_active: true).where(is_day_hospitalize: [false, nil]).order(:name).pluck(:name) },
      other: OTHER
    },
    "day_hospital_specialties" => {
      label: "Specialitățile cu spitalizare de zi",
      names: -> { Specialty.where(is_active: true, has_day_hospitalization: true).order(:name).pluck(:name) },
      other: OTHER
    },
    "medical_staff" => {
      label: "Medicii, kinetoterapeuții și asistenții activi",
      names: -> { SurveyQuestion.medical_staff.map { |m| SurveyQuestion.staff_label(m) } },
      other: OTHER_STAFF
    }
  }.freeze

  # Doctors first, then physiotherapists, then nurses; by surname within each.
  def self.medical_staff
    Member.joins(:profession).where(is_active: true, professions: { slug: MEDICAL_STAFF_PROFESSIONS })
          .includes(:profession, :specialties).to_a
          .sort_by { |m| [MEDICAL_STAFF_PROFESSIONS.index(m.profession.slug), I18n.transliterate(m.last_name.to_s), m.first_name.to_s] }
  end

  # "dr. Mădălina Andriescu (medic, Obstetrică-Ginecologie)",
  # "Ana Pop (asistent medical generalist)". Answers keep this label.
  def self.staff_label(member)
    title = member.academic_title.to_s.strip
    title = "" if title == "-"
    name = [title, member.first_name, member.last_name].map(&:to_s).map(&:strip).reject(&:empty?).join(" ")
    role = member.profession.name.to_s.strip
    field = member.profession.slug == "medic" ? member.specialties.map { |sp| sp.name.sub(/\s*\(.*\)\s*\z/, "") }.join(", ") : nil
    "#{name} (#{[role, field].compact_blank.join(', ')})"
  end

  belongs_to :survey, inverse_of: :questions

  validates :text, presence: true
  validates :kind, inclusion: { in: KINDS.keys }
  validates :options_source, inclusion: { in: SOURCES.keys }, allow_blank: true
  validate :options_fit_kind

  def rating?
    kind == "rating"
  end

  def text?
    kind == "text"
  end

  # The stored options, or for a sourced question the current list from the
  # database plus "other". Read once per instance (one request).
  def options
    return super if options_source.blank? || !SOURCES.key?(options_source)

    source = SOURCES[options_source]
    @source_options ||= (source[:names].call + [source[:other]]).map { |name| { "label" => name, "score" => nil } }
  end

  def options_source=(value)
    @source_options = nil
    super(value.presence)
  end

  def sourced?
    options_source.present?
  end

  # The question without "Cum apreciați…" and its punctuation, for summaries:
  # "Cum apreciați curățenia în spital?" -> "Curățenia în spital".
  SHORT_PREFIXES = [/\ACum apreciați\s+/i, /\ACum evaluați\s+/i].freeze

  def short_text
    t = text.to_s.strip.delete_suffix(":").delete_suffix("?").strip
    SHORT_PREFIXES.each { |re| t = t.sub(re, "") }
    t.empty? ? text : t[0].upcase + t[1..]
  end

  def labels
    options.map { |o| o["label"] }
  end

  def score_for(label)
    options.find { |o| o["label"] == label }&.dig("score")
  end

  # "Foarte bine=100\nBine=67" <-> options, for the admin form.
  def options_text
    options.map { |o| o["score"].nil? ? o["label"] : "#{o['label']}=#{o['score']}" }.join("\n")
  end

  def options_text=(value)
    self.options = value.to_s.lines.map(&:strip).reject(&:blank?).map do |line|
      label, score = line.split("=", 2).map(&:strip)
      { "label" => label, "score" => score.presence && score.to_i.clamp(0, 100) }
    end
  end

  private

  def options_fit_kind
    if sourced?
      errors.add(:options_source, "se folosește doar la întrebările de alegere") unless kind == "choice"
    elsif text?
      errors.add(:options, "nu se folosesc la text liber") if options.any?
    else
      errors.add(:options, "trebuie să aibă cel puțin două variante") if options.size < 2
      errors.add(:options, "au variante duplicate") if labels.uniq.size != labels.size
      if rating? && options.none? { |o| o["score"] }
        errors.add(:options, "au nevoie de scoruri (ex. Foarte bine=100) la o întrebare de evaluare")
      end
    end
  end
end
