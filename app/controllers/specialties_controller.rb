class SpecialtiesController < ApplicationController
  before_action :set_specialty, only: %i[show edit update destroy]
  def new
    @specialty = authorize Specialty.new
  end

  def create
    @specialty = authorize Specialty.new(specialty_params)
    if @specialty.save
      respond_to do |format|
        format.html { redirect_to dashboard_profesii_path, notice: "Specialitatea medicală #{@specialty.name} a fost creată!" }
        format.turbo_stream { flash.now[:notice] = "Specialitatea medicală #{@specialty.name} a fost creată!"}
      end
    else
      render :new, status: :unprocessable_entity, notice: "Ceva nu a mers. Reîncearcă, te rog!"
    end
  end

  def edit
  end

  def update
    if @specialty.update(specialty_params)
      respond_to do |format|
        format.html { redirect_to dashboard_profesii_path, notice: "Specialitatea medicală #{@specialty.name} a fost modificată!" }
        format.turbo_stream {flash.now[:notice] = "Specialitatea medicală #{@specialty.name} a fost modificată!" }
      end
    else
      render :edit, status: :unprocessable_entity, notice: "Ceva nu a mers. Reîncearcă, te rog!"
    end
  end

  def index
    @specialties = policy_scope(Specialty).all
  end

  def show
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
    @specialty = authorize Specialty.find_by(slug: params[:id])
  end

  def specialty_params
    params.require(:specialty).permit(:name, :slug, :description )
  end
end
