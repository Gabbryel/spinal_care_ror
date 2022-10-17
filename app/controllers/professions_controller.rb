class ProfessionsController < ApplicationController
  before_action :set_profession, only: %i[show edit update destroy]

  def new
    @profession = authorize Profession.new
  end

  def create
    @profession = authorize Profession.new(profession_params)
    if @profession.save
      redirect_to dashboard_profesii_path
      flash.alert = 'ok'
    else
      render :new, status: :unprocessable_entity, notice: "Ceva nu a mers. Reîncearcă, te rog!"
    end
  end

  def edit
  end
  
  def update
    if @profession.update(profession_params)
      respond_to do |format|
        redirect_to dashboard_profesii_path
      end
    else
      render :edit, status: :unprocessable_entity, notice: "Ceva nu a mers. Reîncearcă, te rog!"
    end
  end

  def index
    @professions = policy_scope(Profession).all
  end

  def show
  end

  def destroy
    if @profession.destroy
      respond_to do |format|
        format.html { redirect_to dashboard_profesii_path, notice: "Ai șters contul cu succes!" }
        format.turbo_stream
      end
      else
        redirect_to dashboard_profesii_path, notice: "Se pare că acest cont are extra-vieți! Mai încearcă încă o dată ștergerea!"
    end
  end

  private

  def set_profession
    @profession = authorize Profession.find_by!(slug: params[:id])
  end

  def profession_params
    params.require(:profession).permit(:name, :slug)
  end
end
