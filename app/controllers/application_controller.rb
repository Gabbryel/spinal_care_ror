class ApplicationController < ActionController::Base
  include Pundit::Authorization
  before_action :authenticate_user!

  private

  def skip_pundit?
    devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
  end
end
