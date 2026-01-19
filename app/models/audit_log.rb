class AuditLog < ApplicationRecord
  belongs_to :user
  belongs_to :auditable, polymorphic: true, optional: true
  
  ACTIONS = %w[create update destroy login logout view].freeze
  
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :auditable_type, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_type, ->(type) { where(auditable_type: type) }
  scope :by_controller, ->(controller) { where(controller_name: controller) }
  scope :by_request_method, ->(method) { where(request_method: method) }
  scope :this_week, -> { where('created_at >= ?', 1.week.ago) }
  scope :this_month, -> { where('created_at >= ?', 1.month.ago) }
  scope :today, -> { where('created_at >= ?', Time.zone.now.beginning_of_day) }
  scope :excluding_views, -> { where.not(action: 'view') }
  
  def parsed_changes
    change_data.present? ? JSON.parse(change_data) : {}
  rescue JSON::ParserError
    {}
  end
  
  def parsed_params
    params_data.present? ? JSON.parse(params_data) : {}
  rescue JSON::ParserError
    {}
  end
  
  def action_icon
    case action
    when 'create' then 'plus'
    when 'update' then 'pencil'
    when 'destroy' then 'trash'
    when 'login' then 'login'
    when 'logout' then 'logout'
    when 'view' then 'eye'
    else 'question'
    end
  end
  
  def action_color
    case action
    when 'create' then 'success'
    when 'update' then 'warning'
    when 'destroy' then 'danger'
    when 'login' then 'info'
    when 'logout' then 'secondary'
    when 'view' then 'primary'
    else 'secondary'
    end
  end
  
  def auditable_name
    return auditable.try(:name) if auditable.respond_to?(:name)
    return "#{auditable.first_name} #{auditable.last_name}" if auditable.respond_to?(:first_name)
    return auditable.try(:email) if auditable.respond_to?(:email)
    "##{auditable_id}"
  rescue
    "##{auditable_id}"
  end
  
  def full_description
    return description if description.present?
    
    base = "#{action.capitalize} #{auditable_type}"
    base += " #{auditable_name}" if auditable
    base += " via #{request_method}" if request_method.present?
    base += " at #{request_path}" if request_path.present?
    base
  end
  
  def changed_fields
    return [] unless parsed_changes.present?
    
    case action
    when 'update'
      parsed_changes.keys.reject { |k| k.in?(['updated_at', 'created_at', 'id']) }
    when 'create'
      parsed_changes.keys.reject { |k| k.in?(['updated_at', 'created_at', 'id']) }
    else
      []
    end
  end
  
  def request_summary
    parts = []
    parts << request_method if request_method.present?
    parts << request_path if request_path.present?
    parts << "from #{referer}" if referer.present?
    parts << "(#{duration_ms}ms)" if duration_ms.present?
    parts.join(' ')
  end
  
  def browser_info
    return 'Unknown' unless user_agent.present?
    
    agent = user_agent.downcase
    if agent.include?('chrome')
      'Chrome'
    elsif agent.include?('safari')
      'Safari'
    elsif agent.include?('firefox')
      'Firefox'
    elsif agent.include?('edge')
      'Edge'
    else
      'Other'
    end
  end
  
  def device_info
    return 'Unknown' unless user_agent.present?
    
    agent = user_agent.downcase
    return 'Mobile' if agent.include?('mobile') || agent.include?('android') || agent.include?('iphone')
    return 'Tablet' if agent.include?('tablet') || agent.include?('ipad')
    'Desktop'
  end
end
