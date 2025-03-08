class MedicalServicesController < ApplicationController
  before_action :skip_authorization, only: %i[index show_by_specialty]
  skip_before_action :authenticate_user!, only: %i[index show_by_specialty]
  before_action :set_medical_service, only: %i[edit update destroy]

  def new
    @medical_service = authorize MedicalService.new()
  end

  def create
    @medical_service = authorize MedicalService.new(medical_service_params)
    @medical_service.member_id = nil if params[:medical_service][:member_id].nil?
    respond_to do |format|
      if @medical_service.save
        format.html { redirect_to admin_specialty_path(@medical_service.specialty), notice: 'Serviciu medical adăugat!' }
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
    @specialty = @medical_service.specialty
    @medical_service.update(medical_service_params)
    respond_to do |format|
      if @medical_service.save
        format.html { redirect_to admin_specialty_path(@specialty), notice: 'Serviciu medical modificat!'}
        format.json { render :show, status: :updated, location: @medical_service}
      else
        format.turbo_stream
        format.html { render :edit }
        format.json { render json: @medical_service.errors, status: :unprocessable_entity }
      end
    end
  end

  def index
    @medical_services = policy_scope(MedicalService).strict_loading
    # @specialties = Specialty.includes(medical_services: :member).select {|sp| sp.medical_services.count > 0 && sp.is_active }.sort {|a, b| a.name <=> b.name}
    @specialties = Specialty.includes(medical_services: :member).where(is_active: true, medical_services_count: 1..).order(name: :asc)
    # @members = Member.strict_loading.includes(:medical_services).select {|m| m.medical_services.count > 0}.sort {|a, b| a.name <=> b.name}
  end

  def show
  end

  def show_by_specialty
    @specialty = Specialty.find_by(slug: params[:id])
    @specialties = Specialty.all.order(name: :asc)
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
    params.require(:medical_service).permit(:name, :description, :price, :slug, :specialty_id, :member_id, :has_day_hospitalization )
  end
end
