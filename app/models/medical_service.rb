class MedicalService < ApplicationRecord
  belongs_to :specialty
  belongs_to :member, optional: true
  has_rich_text :description
  include SlugHelper
  include CheckSlugHelper
  after_save :slugify, unless: :check_slug
  validates :name, :price, presence: true

  def to_param
    "#{slug}"
  end

  def specialist
    "#{Member.find(self.member_id).name}" if self.member_id
  end

  def memberId
    self.member_id ? self.member_id : -1
  end

  private

  def slug_helper(slug)
    MedicalService.select { |ms| ms.slug == slug}.empty?
  end
end
