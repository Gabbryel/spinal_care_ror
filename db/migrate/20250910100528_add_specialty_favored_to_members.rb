class AddSpecialtyFavoredToMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :specialty_favored, :boolean, default: false, null: true
  end
end
