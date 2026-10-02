# Public questionnaires ("Ești pacientul nostru? Spune-ne părerea ta!").
# Anonymous: no sign-in, no IP or visitor token stored with the answers. Bots
# are kept out by a hidden field, a minimum fill time and a per-IP rate limit
# (the IP only lives in the rate-limit cache for ten minutes).
class SurveysController < ApplicationController
  skip_before_action :authenticate_user!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  MIN_SECONDS = 4

  before_action :set_survey, except: :featured
  rate_limit to: 5, within: 10.minutes, only: :create,
             with: -> { redirect_to public_survey_path(params[:slug]), alert: "Prea multe trimiteri într-un timp scurt. Încercați din nou peste câteva minute." }

  # /parerea-ta: the active questionnaire, or the list when there are several.
  # ?chestionar=<slug> (from a page that knows which one applies) opens that
  # one while it is active and falls back to the list when it is not, so a
  # link on the site never ends in a 404.
  def featured
    # Newest first: the consultations questionnaire (most patients) above the inpatient one.
    surveys = Survey.active.order(created_at: :desc)
    wanted = surveys.find { |s| s.slug == params[:chestionar] }
    return redirect_to(public_survey_path(wanted.slug)) if wanted
    return redirect_to(public_survey_path(surveys.first.slug)) if surveys.one?

    @surveys = surveys
  end

  def show
    @response = @survey.responses.new
    @started = started_token
  end

  def create
    return redirect_to(survey_thanks_path(@survey.slug)) if spam?

    @response = SurveyResponse.build_from(@survey, params.fetch(:answers, {}).permit!)
    @response.source = "web"
    if @response.save
      notify(@response)
      redirect_to survey_thanks_path(@survey.slug)
    else
      @started = started_token
      @submitted = params.fetch(:answers, {}).permit!.to_h
      render :show, status: :unprocessable_entity
    end
  end

  def thanks; end

  private

  def set_survey
    @survey = Survey.active.includes(:questions).find_by!(slug: params[:slug])
  end

  def verifier
    Rails.application.message_verifier(:survey_started)
  end

  def started_token
    verifier.generate(Time.current.to_i, expires_in: 1.day)
  end

  # Filled hidden field, a form sent back faster than a person can read it,
  # or a missing/forged start token: treated as a bot and quietly thanked.
  def spam?
    return true if params[:website].present?

    started = verifier.verified(params[:started].to_s)
    started.nil? || Time.current.to_i - started < MIN_SECONDS
  end

  def notify(response)
    return unless response.alert && response.survey.alert_recipients.any? && ENV["POSTMARK_API_TOKEN"].present?

    SurveyMailer.alert(response).deliver_later
  end
end
