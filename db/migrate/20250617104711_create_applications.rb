class CreateApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :applications do |t|
      t.string :fullname
      t.text :address
      t.text :email
      t.text :phone
      t.references :career, null: false, foreign_key: true
      t.string :emplyment
      t.text :cv

      t.timestamps
    end
  end
end
