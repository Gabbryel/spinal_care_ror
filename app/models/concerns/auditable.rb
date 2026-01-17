module Auditable
  extend ActiveSupport::Concern

  included do
    after_create :log_create
    after_update :log_update
    after_destroy :log_destroy
  end

  private

  def log_create
    create_audit_log('create', changes_for_audit)
  end

  def log_update
    return unless saved_changes.any?
    create_audit_log('update', saved_changes)
  end

  def log_destroy
    create_audit_log('destroy', attributes)
  end

  def create_audit_log(action, change_data)
    return unless Current.user.present?
    
    AuditLog.create!(
      user: Current.user,
      action: action,
      auditable_type: self.class.name,
      auditable_id: id,
      change_data: change_data.to_json,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent
    )
  rescue => e
    Rails.logger.error "Failed to create audit log: #{e.message}"
  end

  def changes_for_audit
    # For create action, capture all attributes except timestamps and internal fields
    attributes.except('created_at', 'updated_at', 'id')
  end
end
