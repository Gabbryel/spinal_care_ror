class MembersController < ApplicationController
  skip_before_action :authenticate_user!, except: %i[new create edit update destroy]
  def new
    @member = authorize Member.new()
  end

  def create
    @member = authorize Member.new(member_params)
    respond_to do |format|
      if @member.save
        format.html { redirect_to personal_dashboard, notice: 'Noul membru al echipei adăugat!'}
        format.json { render :show, status: :created, location: @member}
      else
        format.turbo_stream
        format.html { render :new }
        format.json { render json: @member.errors, status: :unprocessable_entity }
      end
    end
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
    @member = authorize Member.find_by(slug: params[:id])
  end

  def member_params
    params.require(:member).permit(:first_name, :last_name, :profession_id, :specialty_id, :photo, :description, :slug)
  end
end
