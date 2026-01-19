class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :set_current_request_details
  after_action :log_user_activity
  after_action :log_action_view
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
    Current.request_method = request.method
    Current.request_path = request.fullpath
    Current.controller_name = controller_name
    Current.action_name = action_name
    Current.params = params
    Current.referer = request.referer
    Current.request_start_time = Time.current
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
  
  def log_action_view
    return unless current_user && user_signed_in?
    return if devise_controller?
    return if params[:action].in?(%w[create update destroy]) # Already logged by model callbacks
    return if params[:format].in?(%w[json xml]) # Skip API requests
    
    # Log view/index actions for tracking user navigation
    if params[:action].in?(%w[show index edit new])
      duration = Current.request_start_time ? ((Time.current - Current.request_start_time) * 1000).round : nil
      
      AuditLog.create!(
        user: current_user,
        action: 'view',
        auditable_type: controller_name.classify,
        auditable_id: params[:id] || 0,
        description: generate_view_description,
        request_method: request.method,
        request_path: request.fullpath,
        controller_name: controller_name,
        action_name: action_name,
        params_data: sanitize_params.to_json,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        referer: request.referer,
        duration_ms: duration,
        status_code: response.status
      )
    end
  rescue => e
    Rails.logger.error "Failed to log action view: #{e.message}"
  end
  
  def generate_view_description
    case params[:action]
    when 'index'
      "Viewed #{controller_name.humanize.downcase} list"
    when 'show'
      "Viewed #{controller_name.singularize.humanize.downcase} ##{params[:id]}"
    when 'new'
      "Opened form to create #{controller_name.singularize.humanize.downcase}"
    when 'edit'
      "Opened form to edit #{controller_name.singularize.humanize.downcase} ##{params[:id]}"
    else
      "Accessed #{controller_name}##{action_name}"
    end
  end
  
  def sanitize_params
    safe_params = params.to_unsafe_h.deep_dup
    safe_params.delete('password')
    safe_params.delete('password_confirmation')
    safe_params.delete('authenticity_token')
    safe_params
  rescue
    {}
  end
end
