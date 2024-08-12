class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[ home medical_team pacient_page ]

  def home
    @review = Review.new()
    @reviews = Review.all.shuffle || []
    @specialties = Specialty.all.order(name: :asc) || []
    @medics = Member.where(profession_id: Profession.find_by(name: 'medic')).sample(8)
    @kinetos = (Member.where(profession_id: Profession.find_by(name: 'fiziokinetoterapeut' || 'asistent medical BFKT')) + Member.where(profession_id: Profession.find_by(name: 'asistent medical BFKT')))
    @kinetos_to_show = @kinetos.select { |k| k.selected }.sort_by { |k| k.order}
    @schroths = @kinetos.select {|k| k.schroth }
    @beauties = Member.select { |s| s.specialty_id == 13 }
  end

  def medical_team
    @team_members = Member.all.order(:last_name)
    @professions = Profession.all.order(:order)
    @specialties = Specialty.all.order(:name)
  end

  def pacient_page
    @fact = Fact.new()
    @facts = Fact.all
    @specialties = Specialty.all.order(:name)
    @medical_services = MedicalService.all.sample(30)
    @medics = Member.all.select { |m| m.profession.name == 'medic'}
  end
end
