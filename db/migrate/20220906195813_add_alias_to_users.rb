class AddAliasToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :alias, :string
  end
end
