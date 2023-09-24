class AddOrderToProfessions < ActiveRecord::Migration[7.0]
  def change
    add_column :professions, :order, :integer
  end
end
