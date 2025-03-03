class AddIsActiveToMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :is_active, :boolean, default: true, null: true
  end
end
