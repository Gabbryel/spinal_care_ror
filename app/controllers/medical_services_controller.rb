class MedicalServicesController < ApplicationController
  before_action :skip_authorization, only: %i[index]
  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_medical_service, only: %i[edit update destroy]

  def new
    @medical_service = authorize MedicalService.new()
  end

  def create
    @medical_service = authorize MedicalService.new(medical_service_params)
    @medical_service.member_id = nil if params[:medical_service][:member_id].nil?
    respond_to do |format|
      if @medical_service.save
        format.html { redirect_to admin_medical_services_path, notice: 'Serviciu medical adăugat!' }
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
    @medical_service.update(medical_service_params)
    respond_to do |format|
      if @medical_service.save
        format.html { redirect_to admin_medical_services_path, notice: 'Serviciu medical modificat!'}
        format.json { render :show, status: :updated, location: @medical_service}
      else
        format.turbo_stream
        format.html { render :edit }
        format.json { render json: @medical_service.errors, status: :unprocessable_entity }
      end
    end
  end

  def index
    @medical_services = policy_scope(MedicalService).all.order(name: :asc)
    @specialties = Specialty.all.order(name: :asc)
  end

  def show
  end

  def destroy
    respond_to do |format|
      if @medical_service.destroy
        format.html { redirect_to admin_medical_services_path, notice: 'Ștergere efectuată!'}
      end
    end
  end

  private

  def set_medical_service
    @medical_service = authorize MedicalService.find_by!(slug: params[:id])
  end

  def medical_service_params
    params.require(:medical_service).permit(:name, :description, :price, :slug, :specialty_id, :member_id)
  end
end
