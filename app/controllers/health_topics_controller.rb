# Public pages about conditions (/afectiuni/<slug>) and procedures
# (/proceduri/<slug>), and the hub that lists them by specialty. Drafts
# answer 404, except to admins, who see them as a preview.
class HealthTopicsController < ApplicationController
  include NotFoundRendering

  skip_before_action :authenticate_user!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def index
    @topics = HealthTopic.published.includes(:specialties).order(:name).to_a
    @by_specialty = @topics.flat_map { |t| t.specialties.map { |s| [s, t] } }
                           .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
                           .sort_by { |specialty, _| specialty.name }
    @unlinked = @topics.select { |t| t.specialties.empty? }
  end

  def show
    scope = current_user&.admin ? HealthTopic : HealthTopic.published
    @topic = scope.includes(:specialties, :medical_services).find_by(kind: params[:kind], slug: params[:slug])
    return render_not_found unless @topic

    @specialists = @topic.specialists.to_a
    @related = HealthTopic.published.joins(:health_topic_specialties)
                          .where(health_topic_specialties: { specialty_id: @topic.specialty_ids })
                          .where.not(id: @topic.id).distinct.order(:name).limit(6).to_a
  end
end
