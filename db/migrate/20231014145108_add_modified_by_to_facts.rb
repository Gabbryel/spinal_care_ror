class AddModifiedByToFacts < ActiveRecord::Migration[7.0]
  def change
    add_column :facts, :modified_by, :string
  end
end
