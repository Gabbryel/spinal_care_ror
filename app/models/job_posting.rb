class JobPosting < ApplicationRecord
  has_rich_text :description
  
  validates :name, presence: true
  validates :valid_until, presence: true
  
  scope :active, -> { where('valid_until >= ?', Date.today) }
  scope :expired, -> { where('valid_until < ?', Date.today) }
  scope :recent, -> { order(created_at: :desc) }
  
  def active?
    valid_until >= Date.today
  end
  
  def expired?
    !active?
  end
end
