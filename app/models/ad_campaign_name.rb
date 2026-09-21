# The name an admin gives a Google Ads campaign id seen in landing URLs
# (gad_campaignid); the URL carries only the id.
class AdCampaignName < ApplicationRecord
  validates :campaign_id, :name, presence: true
  validates :campaign_id, uniqueness: true
end
