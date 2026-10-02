# The answers: a filterable list (period, negative only, status, specialty),
# CSV export, and each response with a status and an internal note.
module Admin
  class SurveyResponsesController < BaseController
    before_action :set_survey

    PER_PAGE = 20

    def index
      @filter = params.permit(:period, :only, :status, :segment, :weak_on, :page)
      scope = filtered(@survey.responses.order(created_at: :desc, id: :desc))
      respond_to do |format|
        format.html do
          @total = scope.count
          @page = [@filter[:page].to_i, 1].max
          @responses = scope.includes(survey: :questions).offset((@page - 1) * PER_PAGE).limit(PER_PAGE).to_a
          @weak_question = @survey.questions.find { |q| q.id.to_s == @filter[:weak_on].to_s }
        end
        format.csv do
          send_data csv(scope), filename: "#{@survey.slug}-#{Date.current}.csv", type: "text/csv; charset=utf-8"
        end
      end
    end

    # One response, laid out like the form the patient filled in, with the
    # previous and next responses (newest first, as in the list).
    def show
      @response = @survey.responses.find(params[:id])
      # (created_at, id): two answers sent in the same second still have an order.
      at, id = @response.created_at, @response.id
      @newer = @survey.responses.where("(created_at, id) > (?, ?)", at, id).order(:created_at, :id).first
      @older = @survey.responses.where("(created_at, id) < (?, ?)", at, id).order(created_at: :desc, id: :desc).first
    end

    def update
      @response = @survey.responses.find(params[:id])
      attrs = params.require(:survey_response).permit(:status, :staff_note)
      attrs.merge!(reviewed_by_id: current_user.id, reviewed_at: Time.current) if attrs[:status].present? && attrs[:status] != "new"
      @response.update!(attrs)
      redirect_to dashboard_survey_response_path(@survey, @response), notice: "Răspunsul a fost actualizat."
    end

    private

    def set_survey
      @survey = Survey.includes(:questions).find_by!(slug: params[:survey_id])
    end

    def filtered(scope)
      days = @filter[:period].to_i
      scope = scope.where(created_at: days.days.ago..) if days.positive?
      scope = scope.alerts if @filter[:only] == "alerts"
      scope = scope.where(status: @filter[:status]) if SurveyResponse::STATUSES.key?(@filter[:status])
      # Responses that rated this question Satisfăcător or worse (from the interpretation page).
      if @filter[:weak_on].present?
        scope = scope.where("(answers -> ? ->> 'score')::int <= ?", @filter[:weak_on].to_s, SurveyInsights::UNFAVORABLE)
      end
      if @filter[:segment].present?
        question_id, label = @filter[:segment].split(":", 2)
        scope = scope.where("answers -> ? ->> 'label' = ?", question_id, label)
      end
      scope
    end

    def csv(scope)
      require "csv"
      questions = @survey.questions.to_a
      CSV.generate(headers: true) do |out|
        out << ["Data", "Scor", "Negativ", "Motive", "Stare", "Notă internă"] + questions.map(&:text)
        scope.each do |r|
          out << [r.created_at.strftime("%Y-%m-%d %H:%M"), r.score, r.alert ? "da" : "nu", r.alert_reasons.join("; "),
                  SurveyResponse::STATUSES[r.status], r.staff_note] +
                 questions.map { |q| a = r.answer_for(q); a && (a["label"] || a["text"]) }
        end
      end
    end
  end
end
