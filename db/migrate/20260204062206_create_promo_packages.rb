class CreatePromoPackages < ActiveRecord::Migration[8.0]
  def change
    create_table :promo_packages do |t|
      t.string :name
      t.date :valid_until

      t.timestamps
    end
  end
end
