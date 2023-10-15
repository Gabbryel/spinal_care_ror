class AddCreatedByToFacts < ActiveRecord::Migration[7.0]
  def change
    add_column :facts, :created_by, :string
  end
end
