class AuditLog < ApplicationRecord
  belongs_to :user
  belongs_to :auditable, polymorphic: true, optional: true
  
  ACTIONS = %w[create update destroy login logout].freeze
  
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :auditable_type, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_type, ->(type) { where(auditable_type: type) }
  scope :this_week, -> { where('created_at >= ?', 1.week.ago) }
  scope :this_month, -> { where('created_at >= ?', 1.month.ago) }
  
  def parsed_changes
    change_data.present? ? JSON.parse(change_data) : {}
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
    else 'secondary'
    end
  end
  
  def auditable_name
    return auditable.try(:name) if auditable.respond_to?(:name)
    return "#{auditable.first_name} #{auditable.last_name}" if auditable.respond_to?(:first_name)
    "##{auditable_id}"
  rescue
    "##{auditable_id}"
  end
end
