class Specialty < ApplicationRecord
  has_many :members, dependent: :nullify
  has_many :medical_services, dependent: :nullify
  has_rich_text :description
  has_one_attached :photo
  validates :name, presence: true
  include SlugHelper
  include CheckSlugHelper
  include Auditable
  after_save :slugify, unless: :check_slug
  def to_param
    "#{slug}"
  end

  def members_belonging_to_specialty
    self.members
  end

  private

  def slug_helper(slug)
    Specialty.select { |p| p.slug == slug}.empty?
  end
end
