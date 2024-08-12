class AddSelectedToMember < ActiveRecord::Migration[7.1]
  def change
    add_column :members, :selected, :boolean
  end
end
