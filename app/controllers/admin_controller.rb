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

  def professions
    @profession = Profession.new()
    @professions = Profession.all
    @specialty = Specialty.new()
    @specialties = Specialty.all
  end
end
