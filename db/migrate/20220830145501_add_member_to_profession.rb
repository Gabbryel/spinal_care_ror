class AddMemberToProfession < ActiveRecord::Migration[7.0]
  def change
    add_reference :professions, :member, null: false, foreign_key: true
  end
end
