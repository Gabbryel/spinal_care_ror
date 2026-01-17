class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :set_current_request_details
  after_action :log_user_activity
  include Pundit::Authorization

  after_action :verify_authorized, except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

  def default_url_options
    { host: ENV["DOMAIN"] || "localhost:3000" }
  end

  private
  
  def set_current_request_details
    Current.user = current_user
    Current.ip_address = request.remote_ip
    Current.user_agent = request.user_agent
  end

  def skip_pundit?
    devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
  end
  
  def log_user_activity
    return unless current_user && user_signed_in?
    
    # Log login on sign in
    if params[:action] == 'create' && params[:controller] == 'devise/sessions'
      current_user.log_login(request.remote_ip, request.user_agent)
    end
    
    # Log logout on sign out
    if params[:action] == 'destroy' && params[:controller] == 'devise/sessions'
      current_user.log_logout(request.remote_ip, request.user_agent)
    end
  end
end
