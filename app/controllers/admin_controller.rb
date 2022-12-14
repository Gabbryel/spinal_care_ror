class AdminController < ApplicationController
  def dashboard
    @m = Member.new()
    @professions = Profession.all
    @users = User.all.order(email: :asc)

  end

  def personal
    @member = Member.new()
    @members = Member.all.order(last_name: :asc)
    @professions = Profession.all.order(name: :asc)
    @specialties = Specialty.all.order(name: :asc)
  end

  def admin_content
    @profession = Profession.new()
    @professions = Profession.all.order(name: :asc)
    @specialty = Specialty.new()
    @specialties = Specialty.all.order(name: :asc)
  end

  def medical_services
    @medical_service = MedicalService.new()
    @medical_services = MedicalService.all.order(name: :asc)
    @selected_members = Member.all.select { |m| m.medical_services.count > 0}
    @specialties = Specialty.all.order(name: :asc)
  end
end
