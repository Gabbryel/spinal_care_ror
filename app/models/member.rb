class Member < ApplicationRecord
  has_rich_text :description
  has_one_attached :photo
  
  validates :last_name, presence: true
  validates :first_name, presence: true
  validates :profession_id, presence: true
  validates :specialty_id, presence: true

  include SlugHelper
  include CheckSlugHelper
  after_save :slugify, unless: :check_slug

  def to_param
    "#{slug}"
  end

  private

  def slug_helper(slug)
    Member.select { |m| m.slug == slug}.empty?
  end
end
