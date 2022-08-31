class AddSpecialtyToMembers < ActiveRecord::Migration[7.0]
  def change
    add_reference :members, :specialty, null: false, foreign_key: true
  end
end
