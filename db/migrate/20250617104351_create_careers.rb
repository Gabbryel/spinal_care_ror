class CreateCareers < ActiveRecord::Migration[8.0]
  def change
    create_table :careers do |t|
      t.references :profession, null: false, foreign_key: true
      t.text :details

      t.timestamps
    end
  end
end
