class AddDescriptionToSpecialty < ActiveRecord::Migration[7.0]
  def change
    add_column :specialties, :description, :text
  end
end
