class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[ home medical_team ]

  def home
    @review = Review.new()
    @reviews = Review.all.shuffle || []
    @specialties = Specialty.all.order(name: :asc) || []
    @medics = Member.all.where(profession_id: Profession.find_by(name: 'medic')).sample(4)
  end

  def medical_team
    @team_members = Member.all.order(:profession_id)
  end
end
