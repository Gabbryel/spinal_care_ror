class MedicalService < ApplicationRecord
  belongs_to :specialty
  has_rich_text :description
  include SlugHelper
  include CheckSlugHelper
  after_save :slugify, unless: :check_slug

  def to_param
    "#{slug}"
  end

  private

  def slug_helper(slug)
    MedicalService.select { |ms| ms.slug == slug}.empty?
  end
end
