class Review < ApplicationRecord
  validates :rating, presence: true
  validates :author, presence: true
  validates :content, presence: true
  broadcasts_to ->(review) { "reviews" }, inserts_by: :prepend
end
