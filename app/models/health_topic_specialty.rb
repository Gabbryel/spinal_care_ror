class HealthTopicSpecialty < ApplicationRecord
  belongs_to :health_topic
  belongs_to :specialty
end
