class ProfessionsController < ApplicationController
  before_action :set_profession, only: %i[show edit update destroy]

  def new
    @profession = authorize Profession.new
  end

  def create
    @profession = authorize Profession.new(profession_params)
    respond_to do |format|
      if @profession.save
        format.html { redirect_to dashboard_profesii_specialitati_path, notice: 'Profesie nouă adăugată!'}
      else
        format.turbo_stream
        format.html { render :new }
        format.json { render json: @profession.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      @profession.update(profession_params)
      if @profession.save
          format.html { redirect_to dashboard_profesii_specialitati_path, notice: 'Profesie modificată!' }
          format.json { render :show, status: :updated, location: @profession}
      else
        format.turbo_stream
        format.html {render :edit}
        format.json {render json: @profession.errors, status: :unprocessable_entity}
      end
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
        format.html { redirect_to dashboard_profesii_specialitati_path, notice: "Ai șters profesia cu succes!" }
      end
      else
        redirect_to dashboard_profesii_specialitati_path, notice: "Se pare că această profesie are extra-vieți! Mai încearcă încă o dată ștergerea!"
    end
  end

  private

  def set_profession
    @profession = authorize Profession.find_by!(slug: params[:id])
  end

  def profession_params
    params.require(:profession).permit(:name, :slug, :has_specialty, :order)
  end
end
