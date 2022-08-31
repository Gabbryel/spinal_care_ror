class Member < ApplicationRecord
  has_and_belongs_to_many :professions
  has_and_belongs_to_many :specialties
  has_rich_text :description
  has_one_attached :photo
end
