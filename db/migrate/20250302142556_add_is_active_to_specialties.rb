class AddIsActiveToSpecialties < ActiveRecord::Migration[8.0]
  def change
    add_column :specialties, :is_active, :boolean, default: true, null: true
  end
end
