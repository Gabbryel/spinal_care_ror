class PromoPackage < ApplicationRecord
  has_one_attached :photo
  has_rich_text :benefits
  
  validates :name, presence: true
  validates :valid_until, presence: true
  
  scope :active, -> { where('valid_until >= ?', Date.today) }
  scope :expired_recently, -> { where('valid_until < ? AND valid_until >= ?', Date.today, Date.today - 7.days) }
  scope :visible, -> { where('valid_until >= ?', Date.today - 7.days).order(valid_until: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  
  def active?
    valid_until >= Date.today
  end
  
  def expired?
    !active?
  end
  
  def expired_recently?
    expired? && valid_until >= Date.today - 7.days
  end
end
