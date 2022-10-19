class MedicalServicesController < ApplicationController
  before_action :skip_authorization, only: %i[medical_services]
  skip_before_action :authenticate_user!, only: %i[medical_services]
  before_action :set_medical_service, only: %i[edit update destroy]

  def new
    @medical_service = authorize MedicalService.new()
  end

  def create
    @medical_service = authorize MedicalService.new(medical_service_params)
    @medical_service.specialty_id = params[:medical_service][:specialty_id]
    respond_to do |format|
      if @medical_service.save
        format.html { redirect_to dashboard_profesii_path, notice: 'Serviciu medical adăugat!' }
        format.json { render :show, status: :created, location: @medical_service }
      else
        format.turbo_stream
        format.html { render :new }
        format.json { render json: @medical_service.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      @medical_service.update(medical_service_params)
      if @medical_service.save!
        format.html { redirect_to dashboard_profesii_path, notice: 'Serviciu medical modificat!'}
        format.json { render :show, status: :updated, location: @medical_service}
      else
        format.turbo_stream
        format.html { render :edit }
        format.json { render json: @medical_service.errors, status: :unprocessable_entity }
      end
    end
  end

  def index
    @medical_services = policy_scope(MedicalService).all
  end

  def show
  end

  def destroy
    respond_to do |format|
      if @medical_service.destroy
        format.html { redirect_to dashboard_profesii_path, notice: 'Ștergere efectuată!'}
      end
    end
  end

  private

  def set_medical_service
    @medical_service = authorize MedicalService.find_by!(slug: params[:id])
  end

  def medical_service_params
    params.require(:medical_service).permit(:name, :description, :price, :slug, :specialty_id)
  end
end
