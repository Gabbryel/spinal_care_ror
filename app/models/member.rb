class Member < ApplicationRecord
  has_rich_text :description
  has_one_attached :photo
  belongs_to :profession
  belongs_to :specialty, optional: true
  has_many :medical_services, dependent: :nullify
  validates :last_name, :first_name, :profession_id, presence: true
  include SlugHelper
  include CheckSlugHelper
  include Auditable
  after_save :slugify, unless: :check_slug

  def to_param
    "#{slug}"
  end

  def name
    "#{first_name} #{last_name}"
  end

  def form_label
    "#{first_name} #{last_name} - #{specialty_name.downcase}"
  end

  def profession_name
    profession&.name
  end

  def specialty_name
    specialty&.name || ''
  end

  private

  def slug_helper(slug)
    Member.select { |m| m.slug == slug}.empty?
  end
end
