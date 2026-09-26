class MemberSpecialty < ApplicationRecord
  belongs_to :member
  belongs_to :specialty
  validates :specialty_id, uniqueness: { scope: :member_id }
end
