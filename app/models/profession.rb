class Profession < ApplicationRecord
  validates :name, presence: true
  broadcasts_to ->(profession) { "professions" }, inserts_by: :prepend
  include SlugHelper
  after_save :slugify, unless: :slug
  def to_param
    "#{slug}"
  end

  private

  def slug_helper(slug)
    Profession.select { |p| p.slug == slug}.empty?
  end
end
