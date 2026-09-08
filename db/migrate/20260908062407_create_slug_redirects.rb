class CreateSlugRedirects < ActiveRecord::Migration[8.0]
  def change
    create_table :slug_redirects do |t|
      t.string :sluggable_type, null: false
      t.bigint :sluggable_id
      t.string :old_slug, null: false
      t.string :new_slug, null: false

      t.timestamps
    end

    add_index :slug_redirects, %i[sluggable_type old_slug], unique: true
  end
end
