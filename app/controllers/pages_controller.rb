class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[ home medical_team ]

  def home
    @review = Review.new()
    @reviews = Review.all.shuffle || []
    @specialties = Specialty.all.order(name: :asc) || []
    @medics = Member.where(profession_id: Profession.find_by(name: 'medic')).sample(4)
    @kinetos = (Member.where(profession_id: Profession.find_by(name: 'fiziokinetoterapeut' || 'asistent medical BFKT')) + Member.where(profession_id: Profession.find_by(name: 'asistent medical BFKT')))
    @kineto_signature = @kinetos.sample(1)[0]
    kinetos_to_show_last_names = ['Dobreci', 'Caramalău', 'Zediu', 'Cătău']
    @kinetos_to_show = @kinetos.select { |k| kinetos_to_show_last_names.include?(k.last_name)}.sort_by { |k| k.id}.reverse
  end

  def medical_team
    @team_members = Member.all.order(:last_name)
    @professions = Profession.all.order(:order)
    @specialties = Specialty.all.order(:name)
  end
end
