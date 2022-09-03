class Specialty < ApplicationRecord
  has_rich_text :description
  validates :name, presence: true
  broadcasts_to ->(specialty) { "specialties" }, inserts_by: :prepend
  include SlugHelper
  after_save :slugify, unless: :slug
  def to_param
    "#{slug}"
  end

  private

  def slug_helper(slug)
    Specialty.select { |p| p.slug == slug}.empty?
  end
end
