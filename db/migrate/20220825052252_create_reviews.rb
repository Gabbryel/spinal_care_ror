class CreateReviews < ActiveRecord::Migration[7.0]
  def change
    create_table :reviews do |t|
      t.integer :rating
      t.string :author
      t.text :content
      t.boolean :approved, default: false

      t.timestamps
    end
  end
end
