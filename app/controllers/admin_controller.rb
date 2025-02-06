class AdminController < ApplicationController
  layout "dashboard"
  def dashboard
    @m = Member.new()
    @professions = Profession.all
  end
  
  def edit_users
    @users = User.all.order(email: :asc)
  end

  def personal
    @member = Member.new()
    @members = Member.all.order(last_name: :asc)
    @professions = Profession.all.order(order: :asc)
    @specialties = Specialty.all.order(name: :asc)
  end
  
  def professions
    @profession = Profession.new()
    @professions = Profession.all.order(name: :asc)
  end
  
  def specialties
    @specialty = Specialty.new()
    @specialties = Specialty.all.order(name: :asc)
  end

  def medical_services
    @medical_service = MedicalService.new()
    @medical_services = MedicalService.order(name: :asc).to_a
    @selected_members = Member.includes([:medical_services]).select { |m| m.medical_services.count > 0}.to_a
    @specialties = Specialty.all.order(name: :asc)
  end

  def specialty_admin
    @medical_service = MedicalService.new()
    @specialty = Specialty.find_by!(slug: params[:id])
  end

  def info_pacient
    @fact = Fact.new()
    @facts = Fact.all.sort {|x, y| y.updated_at <=> x.updated_at}
  end

  def test
    @profession = Profession.new()
    @professions = Profession.all.order(name: :asc)
    @specialty = Specialty.new()
    @specialties = Specialty.all.order(name: :asc)
  end

end
