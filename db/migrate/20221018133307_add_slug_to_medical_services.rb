class AddSlugToMedicalServices < ActiveRecord::Migration[7.0]
  def change
    add_column :medical_services, :slug, :string
  end
end
