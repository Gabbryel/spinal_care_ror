# /dashboard/chestionare: the questionnaires, their settings and questions,
# and the interpretation of what patients answered.
module Admin
  class SurveysController < BaseController
    before_action :set_survey, except: %i[index new create]

    PERIODS = { "30" => "Ultimele 30 de zile", "90" => "Ultimele 90 de zile", "365" => "Ultimul an", "all" => "Tot" }.freeze

    def index
      @surveys = Survey.order(:created_at).to_a
      @stats = SurveyResponse.group(:survey_id).count
      @recent = SurveyResponse.where(created_at: 30.days.ago..).group(:survey_id).count
      @open_alerts = SurveyResponse.alerts.unreviewed.group(:survey_id).count
      # The site-wide invitation, last 30 days (only visitors who accepted analytics).
      @popup = Ahoy::Event.where(name: "$feedback_popup", time: 30.days.ago..)
                          .group(Arel.sql("properties->>'action'")).count
    end

    def new
      @survey = Survey.new
    end

    # A new questionnaire starts inactive and empty; questions are added on
    # its edit page, then it is switched on.
    def create
      @survey = Survey.new(survey_params.merge(active: false))
      @survey.slug = unique_slug(@survey.title)
      if @survey.save
        redirect_to edit_dashboard_survey_path(@survey), notice: "Chestionarul a fost creat. Adăugați întrebările, apoi activați-l."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @survey.update(survey_params)
        redirect_to edit_dashboard_survey_path(@survey), notice: "Chestionarul a fost salvat."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def insights
      @period = PERIODS.key?(params[:period]) ? params[:period] : "90"
      scope = @survey.responses.includes(:survey)
      if @period == "all"
        current, previous = scope, scope.none
      else
        days = @period.to_i.days
        current = scope.where(created_at: days.ago..)
        previous = scope.where(created_at: (2 * days).ago...days.ago)
      end
      @insights = SurveyInsights.new(@survey, responses: current, previous: previous)
    end

    private

    def set_survey
      @survey = Survey.includes(:questions).find_by!(slug: params[:id])
    end

    def unique_slug(title)
      base = I18n.transliterate(title.to_s).parameterize.presence || "chestionar"
      slug, n = base, 1
      slug = "#{base}-#{n += 1}" while Survey.exists?(slug: slug)
      slug
    end

    def survey_params
      params.require(:survey).permit(:title, :audience, :intro, :thank_you, :active, :alert_emails)
    end
  end
end
