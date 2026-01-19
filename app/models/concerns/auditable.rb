module Auditable
  extend ActiveSupport::Concern

  included do
    after_create :log_create
    after_update :log_update
    after_destroy :log_destroy
  end

  private

  def log_create
    create_audit_log('create', changes_for_audit, generate_create_summary)
  end

  def log_update
    return unless saved_changes.any?
    create_audit_log('update', saved_changes, generate_update_summary)
  end

  def log_destroy
    create_audit_log('destroy', attributes, generate_destroy_summary)
  end

  def create_audit_log(action, change_data, description)
    return unless Current.user.present?
    
    # Build changes summary with before/after
    changes_summary = build_changes_summary(action, change_data)
    
    AuditLog.create!(
      user: Current.user,
      action: action,
      auditable_type: self.class.name,
      auditable_id: id,
      change_data: change_data.to_json,
      changes_summary: changes_summary,
      description: description,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent,
      request_method: Current.request_method,
      request_path: Current.request_path,
      controller_name: Current.controller_name,
      action_name: Current.action_name,
      params_data: sanitize_params(Current.params),
      referer: Current.referer
    )
  rescue => e
    Rails.logger.error "Failed to create audit log: #{e.message}"
  end

  def changes_for_audit
    # For create action, capture all attributes except timestamps and internal fields
    attributes.except('created_at', 'updated_at', 'id')
  end
  
  def build_changes_summary(action, change_data)
    summary_parts = []
    
    case action
    when 'create'
      change_data.each do |field, value|
        next if value.blank?
        summary_parts << "#{field.humanize}: #{format_value(value)}"
      end
    when 'update'
      change_data.each do |field, (old_val, new_val)|
        summary_parts << "#{field.humanize}: #{format_value(old_val)} → #{format_value(new_val)}"
      end
    when 'destroy'
      key_fields = ['name', 'first_name', 'last_name', 'email', 'title'].select { |f| change_data[f].present? }
      if key_fields.any?
        summary_parts << key_fields.map { |f| change_data[f] }.compact.join(' ')
      end
    end
    
    summary_parts.join(", ")
  end
  
  def format_value(value)
    return '(blank)' if value.blank?
    return value.to_s if value.is_a?(String) || value.is_a?(Numeric)
    return value.strftime('%Y-%m-%d') if value.is_a?(Date) || value.is_a?(Time)
    value.to_s.truncate(50)
  end
  
  def generate_create_summary
    identifier = record_identifier
    "Created #{self.class.name.underscore.humanize.downcase}#{identifier}"
  end
  
  def generate_update_summary
    identifier = record_identifier
    changed_fields = saved_changes.keys.reject { |k| k.in?(['updated_at', 'created_at']) }
    fields_list = changed_fields.map(&:humanize).join(', ')
    "Updated #{self.class.name.underscore.humanize.downcase}#{identifier}: #{fields_list}"
  end
  
  def generate_destroy_summary
    identifier = record_identifier
    "Deleted #{self.class.name.underscore.humanize.downcase}#{identifier}"
  end
  
  def record_identifier
    return " '#{name}'" if respond_to?(:name) && name.present?
    return " '#{first_name} #{last_name}'" if respond_to?(:first_name) && first_name.present?
    return " '#{email}'" if respond_to?(:email) && email.present?
    return " '#{title}'" if respond_to?(:title) && title.present?
    " ##{id}"
  end
  
  def sanitize_params(params)
    return '{}' unless params.present?
    
    sanitized = params.to_h.deep_dup
    # Remove sensitive data
    sanitized.delete('password')
    sanitized.delete('password_confirmation')
    sanitized.delete('authenticity_token')
    
    sanitized.to_json
  rescue
    '{}'
  end
end
