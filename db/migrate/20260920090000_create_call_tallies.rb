# Calls the reception actually received, per day, typed in by hand on the
# analytics page. Calibrates the tel: click counts.
class CreateCallTallies < ActiveRecord::Migration[8.0]
  def change
    create_table :call_tallies do |t|
      t.date :date, null: false
      t.integer :calls, null: false, default: 0
      t.string :note
      t.timestamps
    end
    add_index :call_tallies, :date, unique: true
  end
end
