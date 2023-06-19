class AddGodModeToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :god_mode, :boolean, default: false
  end
end
