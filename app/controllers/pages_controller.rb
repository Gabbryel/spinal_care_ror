class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home ]

  def home
    @review = Review.new()
    @reviews = Review.all.shuffle
    @specialties = Specialty.all.order(name: :asc)
    @medics = Profession.find_by(slug: 'medic').members.sample(4)
  end
end
