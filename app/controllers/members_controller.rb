class MembersController < ApplicationController
  skip_before_action :authenticate_user!, except: %i[new create edit update destroy]
  before_action :set_member, only: %i[edit update show destroy]
  rescue_from ActiveRecord::RecordNotFound do |exception|
    @members = Member.where("slug LIKE ?", "%#{params[:id]}%")
    if @members.empty?
      redirect_to echipa_path
      flash.alert = 'Adresă greșită! V-am redirecționat către pagina cu echipa medicală a Clinicii Spinal Care'
    else
      render action: :search_when_error
    end
  end
  
  def new
    @member = authorize Member.new()
  end

  def create
    @member = authorize Member.new(member_params)
    @member.profession_id = params[:member][:profession_id]
    @member.specialty_id = params[:member][:specialty_id] if params[:member][:specialty_id].present?
    respond_to do |format|
      if @member.save
        format.html { redirect_to dashboard_personal_path, notice: 'Noul membru al echipei adăugat!'}
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
    respond_to do |format|
      if params[:member][:specialty_id].nil?
        @member.specialty_id = nil
      end
      @member.update(member_params)
      if @member.save
        format.html { redirect_to dashboard_personal_path, notice: 'Ați modificat cu succes!'}
        format.json { render :show, status: :updated, location: @member}
      else
        format.turbo_stream
        format.html { render :edit }
        format.json { render json: @member.errors, status: :unprocessable_entity }
      end
    end
  end

  def index
    @posts = policy_scope(Member).all
  end

  def show
  end

  def destroy
    respond_to do |format|
      if @member.destroy
        format.html { redirect_to dashboard_personal_path, notice: 'Ștergere efectuată!'}
      end
    end
  end

  private

  def set_member
    @member = authorize Member.find_by!(slug: params[:id])
  end

  def member_params
    params.require(:member).permit(:first_name, :last_name, :profession_id, :specialty_id, :photo, :description, :slug)
  end
end
