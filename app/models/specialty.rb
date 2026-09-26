class Specialty < ApplicationRecord
  has_many :primary_members, class_name: "Member", inverse_of: :specialty, dependent: :nullify
  has_many :member_specialties, dependent: :destroy
  has_many :members, through: :member_specialties
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

  private

  def slug_helper(slug)
    Specialty.select { |p| p.slug == slug}.empty?
  end
end
