module Auditable
  extend ActiveSupport::Concern

  included do
    after_create :log_create
    after_update :log_update
    after_destroy :log_destroy
  end

  private

  def log_create
    attached = audited_attachment_changes.transform_values(&:last).compact
    create_audit_log('create', changes_for_audit.merge(attached), generate_create_summary)
  end

  def log_update
    attachments = audited_attachment_changes
    return if saved_changes.blank? && attachments.blank?

    create_audit_log('update', saved_changes.merge(attachments), generate_update_summary(attachments.keys))
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
  
  def generate_update_summary(extra_fields = [])
    identifier = record_identifier
    changed_fields = saved_changes.keys.reject { |k| k.in?(['updated_at', 'created_at']) } + extra_fields
    fields_list = changed_fields.map(&:humanize).join(', ')
    "Updated #{self.class.name.underscore.humanize.downcase}#{identifier}: #{fields_list}"
  end

  # Attaching or replacing an Active Storage file changes no column, so
  # saved_changes is empty for a photo-only save and the change used to go
  # unrecorded. attachment_changes holds what the save is about to write
  # (Active Storage clears it in after_commit, we read it in after_update),
  # and the association still points at the previous file at this moment.
  def audited_attachment_changes
    return {} unless respond_to?(:attachment_changes)

    attachment_changes.each_with_object({}) do |(name, change), result|
      result["#{name}_file"] = [attached_filename(name), incoming_filename(change)]
    end
  end

  # The in-memory association already points at the incoming file, so the
  # previous name comes from the attachment row still stored in the database
  # (Active Storage replaces it in its own after_save, which runs later).
  def attached_filename(name)
    return nil unless persisted?

    ActiveStorage::Attachment.joins(:blob)
                             .where(record_type: self.class.polymorphic_name, record_id: id, name: name.to_s)
                             .pick("active_storage_blobs.filename").to_s.presence
  rescue StandardError
    nil
  end

  # A DeleteOne change (the file was removed) carries no attachable.
  def incoming_filename(change)
    return nil unless change.respond_to?(:attachable)

    attachable = change.attachable
    case attachable
    when ActiveStorage::Blob then attachable.filename.to_s
    when Hash then attachable[:filename].to_s.presence
    else attachable.try(:original_filename) || attachable.try(:filename).to_s.presence
    end
  rescue StandardError
    nil
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
