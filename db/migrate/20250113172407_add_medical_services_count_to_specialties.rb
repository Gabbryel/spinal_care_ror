class AddMedicalServicesCountToSpecialties < ActiveRecord::Migration[8.0]
  def change
    add_column :specialties, :medical_services_count, :integer
  end
end
