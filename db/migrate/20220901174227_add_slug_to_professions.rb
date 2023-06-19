class AddSlugToProfessions < ActiveRecord::Migration[7.0]
  def change
    add_column :professions, :slug, :string
  end
end
