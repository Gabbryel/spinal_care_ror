# One question of a survey. `options` is an ordered list of
# { "label" => ..., "score" => 0..100 or nil }; a nil score marks an option
# that describes rather than rates (specialty, age, how medicines were paid).
class SurveyQuestion < ApplicationRecord
  include Auditable

  KINDS = { "rating" => "Evaluare (cu scor)", "choice" => "Alegere (fără scor)", "text" => "Text liber" }.freeze

  belongs_to :survey, inverse_of: :questions

  validates :text, presence: true
  validates :kind, inclusion: { in: KINDS.keys }
  validate :options_fit_kind

  def rating?
    kind == "rating"
  end

  def text?
    kind == "text"
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
    if text?
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
