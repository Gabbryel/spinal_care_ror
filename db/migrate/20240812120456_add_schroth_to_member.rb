class AddSchrothToMember < ActiveRecord::Migration[7.1]
  def change
    add_column :members, :schroth, :boolean
  end
end
