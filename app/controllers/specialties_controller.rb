class SpecialtiesController < ApplicationController
  before_action :skip_authorization, only: %i[about all_specialties]
  skip_before_action :authenticate_user!, only: %i[about all_specialties]
  before_action :set_specialty, only: %i[show about edit update destroy about]

  rescue_from ActiveRecord::RecordNotFound do |exception|
    @specialties = Specialty.where("slug LIKE ?", "%#{params[:id]}%")
    if @specialties.empty?
      redirect_to specialitati_medicale_path
      flash.alert = 'Adresă greșită! V-am redirecționat către pagina cu specialitățile medicale din cadrul Clinicii Spinal Care'
    else
      render action: :search_when_error
    end
  end
  
  def new
    @specialty = authorize Specialty.new
  end

  def create
    @specialty = authorize Specialty.new(specialty_params)
    respond_to do |format|
      if @specialty.save
        format.html { redirect_to admin_specialties_path, notice: 'Specialitate medicală adăugată!' }
      else
        format.turbo_stream
        format.html { render :new }
        format.json { render json: @specialty.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      @specialty.update(specialty_params)
      if @specialty.save
        format.html { redirect_to admin_specialties_path, notice: 'Specialitate medicală modificată!' }
        format.json { render :show, status: :updated, location: @specialty}
      else
        format.turbo_stream
        format.html {render :edit}
        format.json {render json: @specialty.errors, status: :unprocessable_entity}
      end
    end
  end

  def index
    @specialties = policy_scope(Specialty).all
  end

  def all_specialties
    @specialties = policy_scope(Specialty).strict_loading.order(name: :asc)
  end

  def show
  end
  def about
    @specialties = [@specialty]
    @all_specialties = Specialty.all.order(:name)
    @specialists = Member.where(has_day_hospitalization: true)
  end

  def destroy
    if @specialty.destroy
      respond_to do |format|
        format.html { redirect_to admin_specialties_path, notice: "Ai șters cu succes!" }
      end
      else
        redirect_to admin_specialties_path, notice: "Se pare că această specialitate medicală are extra-vieți! Mai încearcă încă o dată ștergerea!"
    end
  end

  private

  def set_specialty
    @specialty = authorize Specialty.find_by!(slug: params[:id])
  end

  def specialty_params
    params.require(:specialty).permit(:name, :slug, :description, :photo, :has_day_hospitalization, :is_day_hospitalize, :is_active) 
  end
end
