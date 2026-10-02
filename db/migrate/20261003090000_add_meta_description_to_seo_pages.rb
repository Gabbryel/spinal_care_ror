# A hand-written meta description for specialty, team and patient-info
# pages. Empty means: build one from the page's data (SeoHelper).
class AddMetaDescriptionToSeoPages < ActiveRecord::Migration[8.0]
  def change
    add_column :specialties, :meta_description, :string
    add_column :members, :meta_description, :string
    add_column :facts, :meta_description, :string
  end
end
