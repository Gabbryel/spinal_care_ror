# A questionnaire patients fill in on the site (the first one is the printed
# inpatient satisfaction form). Admins edit it and read the answers from
# /dashboard/chestionare.
class Survey < ApplicationRecord
  include Auditable

  has_many :questions, -> { order(:position) }, class_name: "SurveyQuestion", dependent: :destroy, inverse_of: :survey
  has_many :responses, class_name: "SurveyResponse", dependent: :destroy

  validates :title, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }

  scope :active, -> { where(active: true) }

  # The site-wide invitation checks a cached "any active survey?".
  after_commit { Rails.cache.delete("surveys/any_active") }

  def to_param
    slug
  end

  def active_questions
    questions.select(&:active)
  end

  # Questions grouped by section, in order: the steps of the public form.
  def sections
    active_questions.chunk_while { |a, b| a.section == b.section }.map { |qs| [qs.first.section.presence || "Întrebări", qs] }
  end

  def headline_question
    active_questions.find(&:headline)
  end

  def alert_recipients
    alert_emails.to_s.split(/[,;\s]+/).select { |e| e.match?(URI::MailTo::EMAIL_REGEXP) }
  end
end
