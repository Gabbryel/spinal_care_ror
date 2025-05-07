class AddCustomWidthToFacts < ActiveRecord::Migration[8.0]
  def change
    add_column :facts, :custom_width, :string, default: false, null: true
  end
end
