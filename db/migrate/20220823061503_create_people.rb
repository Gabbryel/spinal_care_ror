class CreatePeople < ActiveRecord::Migration[7.0]
  def change
    create_table :people do |t|
      t.string :first_name
      t.string :last_name
      t.string :profession
      t.string :med_specialty
      t.string :slug

      t.timestamps
    end
  end
end
