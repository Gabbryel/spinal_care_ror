class PromoPackagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]
  skip_after_action :verify_policy_scoped, only: [:index]
  before_action :set_promo_package, only: [:update, :destroy]
  
  layout :resolve_layout
  
  def index
    @promo_packages = PromoPackage.visible
  end

  def create
    @promo_package = PromoPackage.new(promo_package_params)
    authorize @promo_package
    
    if @promo_package.save
      redirect_to admin_promo_packages_path, notice: 'Pachetul promoțional a fost creat cu succes.'
    else
      redirect_to admin_promo_packages_path, alert: 'Eroare la crearea pachetului.'
    end
  end

  def update
    authorize @promo_package
    
    if @promo_package.update(promo_package_params)
      redirect_to admin_promo_packages_path, notice: 'Pachetul promoțional a fost actualizat cu succes.'
    else
      redirect_to admin_promo_packages_path, alert: 'Eroare la actualizarea pachetului.'
    end
  end

  def destroy
    authorize @promo_package
    @promo_package.destroy
    redirect_to admin_promo_packages_path, notice: 'Pachetul promoțional a fost șters cu succes.'
  end
  
  private
  
  def set_promo_package
    @promo_package = PromoPackage.find(params[:id])
  end
  
  def promo_package_params
    params.require(:promo_package).permit(:name, :sub_name, :valid_until, :photo, :initial_price, :discounted_price, :benefits)
  end
  
  def resolve_layout
    action_name.in?(%w[create update destroy]) ? 'dashboard' : 'application'
  end
end
