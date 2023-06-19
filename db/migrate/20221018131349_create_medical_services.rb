class CreateMedicalServices < ActiveRecord::Migration[7.0]
  def change
    create_table :medical_services do |t|
      t.string :name
      t.text :description
      t.integer :price

      t.timestamps
    end
  end
end
