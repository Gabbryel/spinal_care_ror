class Profession < ApplicationRecord
  has_many :members
  validates :name, presence: true
  include SlugHelper
  include CheckSlugHelper
  after_save :slugify, unless: :check_slug
  def to_param
    "#{slug}"
  end

  private

  def slug_helper(slug)
    Profession.select { |p| p.slug == slug}.empty?
  end

end
