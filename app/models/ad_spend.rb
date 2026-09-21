# Ad spend for one month and channel (lei), typed in by an admin on the
# analytics page, so paid contacts get a cost.
class AdSpend < ApplicationRecord
  validates :month, :channel, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :month, uniqueness: { scope: :channel }
end
