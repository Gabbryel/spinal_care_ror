class SpecialtiesController < ApplicationController
  before_action :skip_authorization, only: %i[about all_specialties]
  skip_before_action :authenticate_user!, only: %i[about all_specialties]
  before_action :set_specialty, only: %i[show about edit update destroy]
  def new
    @specialty = authorize Specialty.new
  end

  def create
    @specialty = authorize Specialty.new(specialty_params)
    if @specialty.save
      redirect_to dashboard_profesii_path
    else
      render :new, status: :unprocessable_entity, notice: "Ceva nu a mers. Reîncearcă, te rog!"
    end
  end

  def edit
  end

  def update
    if @specialty.update(specialty_params)
      redirect_to specialty_path(@specialty)
    else
      render :edit, status: :unprocessable_entity, notice: "Ceva nu a mers. Reîncearcă, te rog!"
    end
  end

  def index
    @specialties = policy_scope(Specialty).all
  end

  def all_specialties
    @specialties = policy_scope(Specialty).all.order(name: :asc)
  end

  def show
  end
  def about
  end

  def destroy
    if @specialty.destroy
      respond_to do |format|
        format.html { redirect_to dashboard_profesii_path, notice: "Ai șters cu succes!" }
        format.turbo_stream
      end
      else
        redirect_to dashboard_profesii_path, notice: "Se pare că acest cont are extra-vieți! Mai încearcă încă o dată ștergerea!"
    end
  end

  private

  def set_specialty
    @specialty = authorize Specialty.find_by!(slug: params[:id])
  end

  def specialty_params
    params.require(:specialty).permit(:name, :slug, :description, :photo )
  end
end
