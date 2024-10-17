class AddHasDayHospitalizationToSpecialties < ActiveRecord::Migration[7.1]
  def change
    add_column :specialties, :has_day_hospitalization, :boolean, default: false, null: true
  end
end
