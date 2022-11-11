class Specialty < ApplicationRecord
  has_many :members
  has_many :medical_services
  has_rich_text :description
  has_one_attached :photo
  validates :name, presence: true
  include SlugHelper
  include CheckSlugHelper
  after_save :slugify, unless: :check_slug
  def to_param
    "#{slug}"
  end

  def belongs_to_specialty
    self.members
  end

  private

  def slug_helper(slug)
    Specialty.select { |p| p.slug == slug}.empty?
  end
end
