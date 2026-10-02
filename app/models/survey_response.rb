# One anonymous submission. Answers are stored by question id with the label
# and the score they had when submitted, so later edits to a question's
# wording or scores do not rewrite old answers. No IP, no visitor token.
class SurveyResponse < ApplicationRecord
  include Auditable

  STATUSES = { "new" => "Nou", "reviewed" => "Văzut", "resolved" => "Rezolvat" }.freeze
  # Phrases (matched without diacritics, on word boundaries so "curățenie"
  # does not read as "urât") that make a free-text comment read as a complaint.
  COMPLAINT_PATTERNS = [
    /\breclam/, /\bnemultum/, /\bmurdar/, /\bmizer/, /\bnepolitic/, /\bobraznic/, /\bjign/, /\bignorat/,
    /\bdezamag/, /\bneprofesion/, /\bnu (o |va |il |le )?recomand/, /\burat/, /\bproast/, /\bfrig\b/, /\bnesimt/,
    /\basteptat (foarte |prea )?mult/, /\bnu (a|au|m-a|ne-a) (mai )?venit/, /\bgresit/, /\bscandal/, /\bbatjocor/
  ].freeze
  ALERT_SCORE = 50

  belongs_to :survey
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES.keys }
  validate :required_questions_answered, on: :create

  before_save :compute_score_and_alert, if: :will_save_change_to_answers?

  scope :alerts, -> { where(alert: true) }
  scope :unreviewed, -> { where(status: "new") }

  # Builds a response from the public form: { "<question id>" => label or text }.
  def self.build_from(survey, params)
    given = params.to_h.stringify_keys
    answers = survey.active_questions.each_with_object({}) do |q, h|
      value = given[q.id.to_s].to_s.strip
      next if value.blank?

      if q.text?
        h[q.id.to_s] = { "text" => value.first(4000) }
      elsif q.labels.include?(value)
        h[q.id.to_s] = { "label" => value, "score" => q.score_for(value) }
      end
    end
    survey.responses.new(answers: answers)
  end

  def answer_for(question)
    answers[question.id.to_s]
  end

  # How an answer reads: good (Bine or better, Da), mid (Da, uneori; Mulțumit),
  # weak (Satisfăcător or worse, Nu, Niciodată) or neutral (no score).
  def self.band(score)
    return :neutral if score.nil?
    return :good if score >= SurveyInsights::FAVORABLE
    return :weak if score <= SurveyInsights::UNFAVORABLE

    :mid
  end

  # Who answered, from the grouping questions (age, sex, specialty…).
  def profile
    survey.active_questions.select(&:segment).filter_map do |q|
      label = answer_for(q)&.dig("label")
      [q.short_text, label] if label
    end
  end

  # The rated answers sorted into what went well, what was so-so and what did
  # not, for the plain-language summary of one response.
  def highlights
    survey.questions.select(&:rating?).each_with_object({ good: [], mid: [], weak: [] }) do |q, h|
      a = answer_for(q)
      next unless a && a["score"]

      h[self.class.band(a["score"])] << [q, a["label"]]
    end
  end

  def weak_count
    answers.values.count { |a| a["score"] && a["score"] <= SurveyInsights::UNFAVORABLE }
  end

  def comment
    answers.values.filter_map { |a| a["text"] }.join("\n\n").presence
  end

  def headline_label
    q = survey.headline_question
    q && answer_for(q)&.dig("label")
  end

  private

  def required_questions_answered
    missing = survey.active_questions.select { |q| q.required && answer_for(q).blank? }
    return if missing.empty?

    errors.add(:base, "Vă rugăm să răspundeți și la: #{missing.map { |q| q.text.delete_suffix(':').delete_suffix('?') }.join('; ')}.")
  end

  def compute_score_and_alert
    scored = answers.values.filter_map { |a| a["score"] }
    self.score = scored.any? ? (scored.sum.to_f / scored.size).round(1) : nil

    reasons = []
    headline = survey.headline_question
    if headline && answer_for(headline)&.dig("score") == 0
      reasons << "Impresie generală: #{answer_for(headline)['label']}"
    end
    reasons << "Scor general #{score.round}/100" if score && score < ALERT_SCORE
    worst = answers.count { |_, a| a["score"] == 0 }
    reasons << "#{worst} răspunsuri la nivelul cel mai slab" if worst >= 3
    reasons << "Comentariu cu o posibilă reclamație" if complaint?(comment)
    self.alert_reasons = reasons
    self.alert = reasons.any?
  end

  def complaint?(text)
    return false if text.blank?

    folded = I18n.transliterate(text.downcase)
    COMPLAINT_PATTERNS.any? { |pattern| folded.match?(pattern) }
  end
end
