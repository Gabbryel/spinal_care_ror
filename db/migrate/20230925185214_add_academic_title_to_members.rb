class AddAcademicTitleToMembers < ActiveRecord::Migration[7.0]
  def change
    add_column :members, :academic_title, :string
  end
end
