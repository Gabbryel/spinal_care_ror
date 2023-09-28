class AddDoctorGradeToMembers < ActiveRecord::Migration[7.0]
  def change
    add_column :members, :doctor_grade, :string, default: ''
  end
end
