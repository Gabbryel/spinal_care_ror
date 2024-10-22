class AddIsDayHospitalizeToSpecialty < ActiveRecord::Migration[7.1]
  def change
    add_column :specialties, :is_day_hospitalize, :boolean, default: false, null: true
  end
end
