class AddHasOwnPageToMembers < ActiveRecord::Migration[7.1]
  def change
    add_column :members, :has_own_page, :boolean, default: false
  end
end
