class AddSlugToSpecialty < ActiveRecord::Migration[7.0]
  def change
    add_column :specialties, :slug, :string
  end
end
