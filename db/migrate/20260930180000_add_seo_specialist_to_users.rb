# SEO specialists see the analytics section of the dashboard and nothing else.
class AddSeoSpecialistToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :seo_specialist, :boolean, default: false, null: false
  end
end
