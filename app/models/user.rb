class User < ApplicationRecord
  include Auditable
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  def log_login(ip_address, user_agent)
    AuditLog.create!(
      user: self,
      action: 'login',
      auditable_type: 'User',
      auditable_id: id,
      change_data: { email: email, logged_in_at: Time.current }.to_json,
      ip_address: ip_address,
      user_agent: user_agent
    )
  rescue => e
    Rails.logger.error "Failed to log login: #{e.message}"
  end
  
  def log_logout(ip_address, user_agent)
    AuditLog.create!(
      user: self,
      action: 'logout',
      auditable_type: 'User',
      auditable_id: id,
      change_data: { email: email, logged_out_at: Time.current }.to_json,
      ip_address: ip_address,
      user_agent: user_agent
    )
  rescue => e
    Rails.logger.error "Failed to log logout: #{e.message}"
  end
end
