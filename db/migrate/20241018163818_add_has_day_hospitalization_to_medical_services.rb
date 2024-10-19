class AddHasDayHospitalizationToMedicalServices < ActiveRecord::Migration[7.1]
  def change
    add_column :medical_services, :has_day_hospitalization, :boolean, default: false, null: true
  end
end
