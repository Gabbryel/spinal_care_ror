class MedicinesConsumptionsController < ApplicationController
  layout "dashboard"
  before_action :set_medicines_consumption, only: %i[update destroy]

  def create
    @medicines_consumption = authorize MedicinesConsumption.new(medicines_consumption_params)
    if @medicines_consumption.save
      redirect_to dashboard_consum_medicamente_path, notice: 'Consum adăugat cu succes!'
    else
      redirect_to dashboard_consum_medicamente_path, alert: @medicines_consumption.errors.full_messages.to_sentence
    end
  end

  def update
    if @medicines_consumption.update(medicines_consumption_params)
      redirect_to dashboard_consum_medicamente_path, notice: 'Consum actualizat cu succes!'
    else
      redirect_to dashboard_consum_medicamente_path, alert: @medicines_consumption.errors.full_messages.to_sentence
    end
  end

  def destroy
    @medicines_consumption.destroy
    redirect_to dashboard_consum_medicamente_path, notice: 'Consum șters cu succes!'
  end
  
  private
  
  def set_medicines_consumption
    @medicines_consumption = authorize MedicinesConsumption.find(params[:id])
  end
  
  def medicines_consumption_params
    params.require(:medicines_consumption).permit(:month, :year, :consumption)
  end
end