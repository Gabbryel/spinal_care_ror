class AddOrderToMember < ActiveRecord::Migration[7.1]
  def change
    add_column :members, :order, :integer
  end
end
