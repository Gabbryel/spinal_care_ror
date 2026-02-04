class AddSubNameToPromoPackages < ActiveRecord::Migration[8.0]
  def change
    add_column :promo_packages, :sub_name, :string
  end
end
