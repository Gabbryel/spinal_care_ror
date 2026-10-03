# A page about a condition (/afectiuni/<slug>) or a procedure
# (/proceduri/<slug>). Drafts stay off the site, the sitemap and the
# specialty pages until published.
class HealthTopic < ApplicationRecord
  include Auditable
  include CleanRichText

  KINDS = {
    "afectiune" => { label: "Afecțiune", plural: "Afecțiuni", path: "afectiuni", schema: "MedicalCondition" },
    "procedura" => { label: "Procedură sau investigație", plural: "Proceduri și investigații", path: "proceduri", schema: "MedicalProcedure" }
  }.freeze

  has_rich_text :body
  cleans_rich_text :body
  has_many :health_topic_specialties, dependent: :destroy
  has_many :specialties, -> { order(:name) }, through: :health_topic_specialties
  has_many :health_topic_services, dependent: :destroy
  has_many :medical_services, -> { order(:name) }, through: :health_topic_services

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS.keys }
  validates :slug, presence: true, uniqueness: { scope: :kind }, format: { with: /\A[a-z0-9-]+\z/ }
  validates :summary, length: { maximum: 400 }

  before_validation :fill_slug
  before_save :stamp_published_at

  scope :published, -> { where(published: true) }

  # The menus check a cached "any published?".
  after_commit { Rails.cache.delete("health_topics/any_published") }

  def kind_info
    KINDS[kind]
  end

  def public_path
    "/#{kind_info[:path]}/#{slug}"
  end

  # Doctors and therapists who treat it: the active, profiled members of its specialties.
  def specialists
    Member.joins(:member_specialties)
          .where(member_specialties: { specialty_id: specialty_ids }, is_active: true, has_own_page: true)
          .includes(:profession, :specialties, photo_attachment: :blob).distinct.order(:last_name)
  end

  # "Întrebare?\nRăspuns" blocks separated by a blank line <-> faqs, for the
  # dashboard form.
  def faqs_text
    faqs.map { |f| "#{f['q']}\n#{f['a']}" }.join("\n\n")
  end

  def faqs_text=(value)
    self.faqs = value.to_s.split(/\r?\n\s*\r?\n/).filter_map do |block|
      question, *answer = block.strip.lines.map(&:strip)
      next if question.blank? || answer.join.blank?

      { "q" => question, "a" => answer.join(" ") }
    end
  end

  private

  def fill_slug
    self.slug = I18n.transliterate(name.to_s).parameterize if slug.blank? && name.present?
  end

  def stamp_published_at
    self.published_at ||= Time.current if published
  end
end
