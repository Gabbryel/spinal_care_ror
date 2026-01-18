class MedicalServicesController < ApplicationController
  before_action :skip_authorization, only: %i[index show_by_specialty]
  skip_before_action :authenticate_user!, only: %i[index show_by_specialty]
  skip_after_action :verify_policy_scoped, only: %i[index show_by_specialty]
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
        format.html { render :new, status: :unprocessable_entity }
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
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @medical_service.errors, status: :unprocessable_entity }
      end
    end
  end

  def index
    # Optimized query: eager load associations with ordered medical services
    @specialties = Specialty
      .includes(medical_services: :member)
      .where(is_active: true)
      .where('medical_services_count > 0')
      .order(name: :asc)
      .references(:medical_services)
    
    # Order medical services by member_id and name in SQL for better performance
    @specialties.each do |specialty|
      specialty.association(:medical_services).target.sort_by! { |ms| [ms.member_id ? 0 : 1, ms.member_id || 0, ms.name] }
    end
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
