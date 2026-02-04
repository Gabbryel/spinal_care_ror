class AddPricingFieldsToPromoPackages < ActiveRecord::Migration[8.0]
  def change
    add_column :promo_packages, :initial_price, :decimal, precision: 10, scale: 2
    add_column :promo_packages, :discounted_price, :decimal, precision: 10, scale: 2
  end
end
