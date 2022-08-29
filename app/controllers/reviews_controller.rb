class ReviewsController < ApplicationController
  skip_before_action :authenticate_user!, except: %i[edit update destroy]
  before_action :set_review, only: %i[edit update destroy]
  def new
    @review = authorize Review.new()
  end

  def create
    @review = authorize Review.new(review_params)
    if @review.save
      redirect_to root_path(anchor: 'reviews-approved')
      flash.alert = 'Recenzie creată. Va fi publicată după aprobare!'
    else
      render :new
    end
  end

  def edit
  end

  def update
    @review.update(review_params)
    if @review.save!
      redirect_to admin_path(anchor: "reviews-section")
    end
  end

  def destroy
    if @review.destroy
      redirect_to admin_path(anchor: "reviews-section")
    end
  end

  private

  def review_params
    params.require(:review).permit(:content, :rating, :approved, :author)
  end

  def set_review
    @review = authorize Review.find(params[:id])
  end
end

