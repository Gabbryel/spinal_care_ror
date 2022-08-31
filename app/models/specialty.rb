class Specialty < ApplicationRecord
  has_and_belongs_to_many :members
  has_rich_text :description
end
