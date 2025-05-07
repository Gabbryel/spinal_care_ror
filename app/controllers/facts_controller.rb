class FactsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[ show ]
  before_action :set_fact, only: %i[edit update show about destroy]

  rescue_from ActiveRecord::RecordNotFound do |exception|
    @facts = Fact.where("slug LIKE ?", "%#{params[:id]}%")
    if @facts.empty?
      redirect_to informatii_pacient_path
      flash.alert = 'Adresă greșită! V-am redirecționat către pagina cu informații pentru pacient a Clinicii Spinal Care'
    else
      render action: :search_when_error
    end
  end

  def new
    @fact = authorize Fact.new()
  end

  def create
    @fact = authorize Fact.new(fact_params)
    respond_to do |format|
      if @fact.save
        format.html { redirect_to dashboard_info_pacient_path, notice: 'Informare nouă adăugată!'}
        format.json { render :show, status: :created, location: @fact}
      else
        format.turbo_stream
        format.html { render :new }
        format.json { render json: @fact.errors, status: :unprocessable_entity }
      end
    end
  end

  def show
    @facts = [@fact]
    @all_facts = Fact.all.order(:updated_at)
  end

  def edit
  end

  def update
    respond_to do |format|
      @fact.update(fact_params)
      if @fact.save
        format.html { redirect_to dashboard_info_pacient_path, notice: 'Ați modificat cu succes!'}
        format.json { render :show, status: :updated, location: @fact}
      else
        format.turbo_stream
        format.html { render :edit }
        format.json { render json: @fact.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    respond_to do |format|
      if @fact.destroy
        format.html { redirect_to dashboard_info_pacient_path, notice: 'Ștergere efectuată!'}
      end
    end
  end

  private

  def set_fact
    @fact = authorize Fact.find_by!(slug: params[:id])
  end

  def fact_params
    params.require(:fact).permit(:name, :description, :custom_width, :slug, :created_by, :modified_by)
  end
end
