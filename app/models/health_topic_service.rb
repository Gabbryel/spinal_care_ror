class HealthTopicService < ApplicationRecord
  belongs_to :health_topic
  belongs_to :medical_service
end
