class AddHasSpecialtyToProfessions < ActiveRecord::Migration[7.0]
  def change
    add_column :professions, :has_specialty, :boolean, default: false
  end
end
