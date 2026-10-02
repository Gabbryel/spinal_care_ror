# Adding, editing, reordering and retiring a questionnaire's questions. A
# question that already has answers is deactivated rather than deleted, so
# old responses keep their meaning.
module Admin
  class SurveyQuestionsController < BaseController
    before_action :set_survey
    before_action :set_question, except: :create

    def create
      question = @survey.questions.new(question_params)
      question.position = (@survey.questions.maximum(:position) || 0) + 1
      if question.save
        redirect_to edit_dashboard_survey_path(@survey, anchor: "q-#{question.id}"), notice: "Întrebarea a fost adăugată."
      else
        redirect_to edit_dashboard_survey_path(@survey, anchor: "new-question"), alert: "Întrebarea nu a fost adăugată: #{question.errors.full_messages.to_sentence}."
      end
    end

    def update
      if @question.update(question_params)
        redirect_to edit_dashboard_survey_path(@survey, anchor: "q-#{@question.id}"), notice: "Întrebarea a fost salvată."
      else
        redirect_to edit_dashboard_survey_path(@survey, anchor: "q-#{@question.id}"), alert: "Întrebarea nu a fost salvată: #{@question.errors.full_messages.to_sentence}."
      end
    end

    def move
      sibling = params[:direction] == "up" ? @survey.questions.where("position < ?", @question.position).last
                                           : @survey.questions.where("position > ?", @question.position).first
      if sibling
        SurveyQuestion.transaction do
          a, b = @question.position, sibling.position
          @question.update!(position: b)
          sibling.update!(position: a)
        end
      end
      redirect_to edit_dashboard_survey_path(@survey, anchor: "q-#{@question.id}")
    end

    def destroy
      answered = @survey.responses.where("jsonb_exists(answers, ?)", @question.id.to_s).exists?
      if answered
        @question.update!(active: false)
        redirect_to edit_dashboard_survey_path(@survey), notice: "Întrebarea are deja răspunsuri, așa că a fost dezactivată (nu mai apare în formular, răspunsurile vechi rămân)."
      else
        @question.destroy!
        redirect_to edit_dashboard_survey_path(@survey), notice: "Întrebarea a fost ștearsă."
      end
    end

    private

    def set_survey
      @survey = Survey.find_by!(slug: params[:survey_id])
    end

    def set_question
      @question = @survey.questions.find(params[:id])
    end

    # A question whose options come from the database ignores typed options.
    def question_params
      attrs = params.require(:survey_question).permit(:section, :text, :kind, :options_source, :options_text, :required, :segment, :headline, :active)
      attrs.delete(:options_text) if attrs[:options_source].present?
      attrs
    end
  end
end
