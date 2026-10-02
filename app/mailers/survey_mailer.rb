# Tells the clinic's management about a negative questionnaire response.
class SurveyMailer < ApplicationMailer
  def alert(response)
    @response = response
    @survey = response.survey
    @url = dashboard_survey_response_url(@survey, response)
    mail(to: @survey.alert_recipients, subject: "Chestionar: răspuns negativ (#{response.alert_reasons.first})")
  end
end
