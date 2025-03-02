class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[ home medical_team pacient_page ]

  def home
    # @review = Review.new()
    # @reviews = Review.all.shuffle || []
    @specialties = Specialty.strict_loading.order(name: :asc) || []
    @members = Member.includes([:profession, :specialty, :photo_attachment]).order(:last_name).to_a || [].to_a
    @medics = @members.select {|m| m.profession.slug == 'medic'}.sample(7)
    @kinetos = @members.select { |m| m.profession.slug == 'fiziokinetoterapeut' || 'asistent-medical-bfkt' }
    @kinetos_to_show = @kinetos.select { |k| k.selected }.sort_by { |k| k.order }
    @schroths = @kinetos.select {|k| k.schroth }
    @beauties = @members.select {|m| m.profession.slug == 'tehnician-estetica-medicala'}
  end

  def medical_team
    @team_members = Member.includes([:specialty, :photo_attachment]).order(:last_name)
    @professions = Profession.all.order(:order).includes([:members])
    @specialties = Specialty.all.order(:name).includes([:members])
  end

  def pacient_page
    @fact = Fact.new()
    @facts = Fact.all
    @specialties = Specialty.all.order(:name)
    @medical_services = MedicalService.all.sample(30)
    @medics = Member.all.select { |m| m.profession.name == 'medic'}
  end
end
