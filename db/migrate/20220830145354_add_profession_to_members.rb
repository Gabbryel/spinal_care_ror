class AddProfessionToMembers < ActiveRecord::Migration[7.0]
  def change
    add_reference :members, :profession, null: false, foreign_key: true
  end
end
