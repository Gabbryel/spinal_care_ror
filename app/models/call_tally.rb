# Calls the reception actually received on a day (typed in by an admin on the
# analytics page), so tel: clicks can be compared with real calls.
class CallTally < ApplicationRecord
  validates :date, presence: true, uniqueness: true
  validates :calls, numericality: { greater_than_or_equal_to: 0, only_integer: true }
end
