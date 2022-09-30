class Member < ApplicationRecord
  has_rich_text :description
  has_one_attached :photo
  belongs_to :profession
  belongs_to :specialty
  validates :last_name, :first_name, :profession_id, :specialty_id, :description, presence: true
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
