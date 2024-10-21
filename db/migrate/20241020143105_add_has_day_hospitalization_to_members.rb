class AddHasDayHospitalizationToMembers < ActiveRecord::Migration[7.1]
  def change
    add_column :members, :has_day_hospitalization, :boolean, default: false, null: true
  end
end
