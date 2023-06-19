class AddSpecialtyToMedicalServices < ActiveRecord::Migration[7.0]
  def change
    add_reference :medical_services, :specialty, null: false, foreign_key: true
  end
end
