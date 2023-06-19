class AddMemberToMedicalServices < ActiveRecord::Migration[7.0]
  def change
    add_reference :medical_services, :member, null: true, foreign_key: true
  end
end
