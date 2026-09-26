class Member < ApplicationRecord
  has_rich_text :description
  has_one_attached :photo
  belongs_to :profession
  # The primary specialty: the one the card links to and the meta
  # description names. It is always one of `specialties` too.
  belongs_to :specialty, optional: true
  has_many :member_specialties, dependent: :destroy
  has_many :specialties, -> { order(:name) }, through: :member_specialties
  has_many :medical_services, dependent: :nullify
  validates :last_name, :first_name, :profession_id, presence: true
  include SlugHelper
  include CheckSlugHelper
  include Auditable
  # Before slugify: it saves the record again from inside after_save.
  before_save :prepare_specialties
  after_save :write_specialties
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

  # Primary specialty first, then the others by name.
  def ordered_specialties
    specialties.sort_by { |s| s.id == specialty_id ? 0 : 1 }
  end

  # Assigning the ids only records them; the join rows are written with the
  # member's own save. has_many :through would otherwise write them right away,
  # even when the save then fails validation, and the change would never reach
  # the activity journal.
  def specialty_ids=(ids)
    @pending_specialty_ids = Array(ids).reject(&:blank?).map(&:to_i).uniq
  end

  def specialty_ids
    @pending_specialty_ids || super
  end

  private

  def prepare_specialties
    current = new_record? ? [] : member_specialties.pluck(:specialty_id)
    wanted = @pending_specialty_ids || current
    self.specialty_id = wanted.first if specialty_id.nil? && wanted.any?
    wanted |= [specialty_id] if specialty_id
    @specialty_ids_to_write = wanted

    @audited_specialty_changes =
      if wanted.sort == current.sort
        {}
      else
        names = Specialty.where(id: current | wanted).pluck(:id, :name).to_h
        { "specialties" => [current, wanted].map { |ids| ids.map { |id| names[id] }.compact.sort.join(", ").presence } }
      end
  end

  def write_specialties
    return unless (wanted = @specialty_ids_to_write)

    member_specialties.where.not(specialty_id: wanted).destroy_all
    (wanted - member_specialties.pluck(:specialty_id)).each { |id| member_specialties.create!(specialty_id: id) }
    specialties.reset
  ensure
    @pending_specialty_ids = nil
    @specialty_ids_to_write = nil
    @audited_specialty_changes = nil
  end

  def audited_association_changes
    @audited_specialty_changes || {}
  end

  def slug_helper(slug)
    Member.select { |m| m.slug == slug}.empty?
  end
end
