class AddMemberToSpecialty < ActiveRecord::Migration[7.0]
  def change
    add_reference :specialties, :member, null: false, foreign_key: true
  end
end
