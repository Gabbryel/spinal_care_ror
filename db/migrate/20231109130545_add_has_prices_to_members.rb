class AddHasPricesToMembers < ActiveRecord::Migration[7.1]
  def change
    add_column :members, :has_prices, :boolean, default: false
  end
end
