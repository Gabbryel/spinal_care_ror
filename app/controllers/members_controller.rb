class MembersController < ApplicationController
  skip_before_action :authenticate_user!, except: %i[new create edit update destroy]
  def new
  end

  def create
  end

  def edit
  end

  def update
  end

  def index
  end

  def show
  end

  def destroy
  end

  private

  def set_member

  end

  def member_params
    require(:member).permit(:first_name, :last_name, :profession, :specialty, :photo, :description)
  end
end
