class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[ home medical_team pacient_page ]

  def home
    @review = Review.new()
    @reviews = Review.all.shuffle || []
    @specialties = Specialty.all.order(name: :asc) || []
    @medics = Member.where(profession_id: Profession.find_by(name: 'medic')).sample(8)
    @kinetos = (Member.where(profession_id: Profession.find_by(name: 'fiziokinetoterapeut' || 'asistent medical BFKT')) + Member.where(profession_id: Profession.find_by(name: 'asistent medical BFKT')))
    @kineto_signature = @kinetos.sample(1)[0]
    kinetos_to_show_last_names = ['Dobreci', 'Caramalău', 'Prihoancă', 'Cătău']
    @kinetos_to_show = @kinetos.select { |k| kinetos_to_show_last_names.include?(k.last_name)}.sort_by { |k| k.id}.reverse
    @schroths = @kinetos.select {|s| s.specialty_id == 18 }
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
