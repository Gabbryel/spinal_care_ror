class EnhanceAuditLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :audit_logs, :request_method, :string
    add_column :audit_logs, :request_path, :string
    add_column :audit_logs, :controller_name, :string
    add_column :audit_logs, :action_name, :string
    add_column :audit_logs, :params_data, :text
    add_column :audit_logs, :changes_summary, :text
    add_column :audit_logs, :description, :text
    add_column :audit_logs, :referer, :string
    add_column :audit_logs, :duration_ms, :integer
    add_column :audit_logs, :status_code, :integer
    
    add_index :audit_logs, :controller_name
    add_index :audit_logs, :action_name
    add_index :audit_logs, :request_method
    add_index :audit_logs, [:user_id, :created_at]
  end
end
