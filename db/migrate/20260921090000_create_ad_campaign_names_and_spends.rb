# Admin-typed context for paid traffic: names for Google Ads campaign ids and
# monthly ad spend per channel.
class CreateAdCampaignNamesAndSpends < ActiveRecord::Migration[8.0]
  def change
    create_table :ad_campaign_names do |t|
      t.string :campaign_id, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :ad_campaign_names, :campaign_id, unique: true

    create_table :ad_spends do |t|
      t.date :month, null: false
      t.string :channel, null: false, default: 'paid_google'
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0
      t.string :note
      t.timestamps
    end
    add_index :ad_spends, [:month, :channel], unique: true
  end
end
