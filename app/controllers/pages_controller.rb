class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[ home medical_team ]

  def home
    @review = Review.new()
    @reviews = Review.all.shuffle || []
    @specialties = Specialty.all.order(name: :asc) || []
    @medics = Member.where(profession_id: Profession.find_by(name: 'medic')).sample(4)
    @kinetos = (Member.where(profession_id: Profession.find_by(name: 'fiziokinetoterapeut' || 'asistent medical BFKT')) + Member.where(profession_id: Profession.find_by(name: 'asistent medical BFKT'))).sample(4)
    @kineto_signature = @kinetos.sample(1)[0]
  end

  def medical_team
    @team_members = Member.all.order(:order)
  end
end
