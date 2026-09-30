class User < ApplicationRecord
  include Auditable
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  has_many :audit_logs, dependent: :destroy

  # SEO specialists see the dashboard's analytics section and nothing else.
  # The attribute check keeps the app working in the minutes between a deploy
  # and the migration that adds the column (no release phase on Heroku).
  def seo_specialist?
    has_attribute?(:seo_specialist) && self[:seo_specialist] == true
  end

  def analytics_access?
    admin || seo_specialist?
  end

  # Signed in only for the analytics: every other dashboard page sends them there.
  def analytics_only?
    !admin && seo_specialist?
  end
  
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
