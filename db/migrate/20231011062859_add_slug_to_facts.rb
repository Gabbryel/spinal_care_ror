class AddSlugToFacts < ActiveRecord::Migration[7.0]
  def change
    add_column :facts, :slug, :string, default: ''
  end
end
