class AddFounderToMember < ActiveRecord::Migration[7.1]
  def change
    add_column :members, :founder, :boolean, default: false, null: true
  end
end
