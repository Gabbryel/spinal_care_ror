class AddSeoTitleToPublicRecords < ActiveRecord::Migration[8.0]
  def change
    add_column :specialties, :seo_title, :string
    add_column :members, :seo_title, :string
    add_column :facts, :seo_title, :string
  end
end
