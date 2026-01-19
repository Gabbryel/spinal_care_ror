class AdminController < ApplicationController
  layout "dashboard"
  def dashboard
    @m = Member.new()
    @professions = Profession.all
  end
  
  def analytics
    # Period filter setup
    @period = params[:period] || '30'
    @start_date = calculate_start_date(@period)
    @custom_start_date = params[:custom_start_date]
    @custom_end_date = params[:custom_end_date]
    
    # If custom period, override start_date
    if @period == 'custom' && @custom_start_date.present? && @custom_end_date.present?
      @start_date = Time.zone.parse(@custom_start_date).beginning_of_day
      @end_date = Time.zone.parse(@custom_end_date).end_of_day
    else
      @end_date = Time.zone.now
    end
    
    # Audit data (not filtered by period)
    @total_members = Member.count
    @total_services = MedicalService.count
    @total_specialties = Specialty.count
    @total_professions = Profession.count
    @total_facts = Fact.count
    @total_users = User.count
    @admin_users = User.where(admin: true).count
    @god_mode_users = User.where(god_mode: true).count
    
    # Visitor analytics (exclude dashboard/admin pages) - filtered by period
    public_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                                .where('started_at >= ? AND started_at <= ?', @start_date, @end_date)
    
    @total_visits = public_visits.count
    @total_visits_today = public_visits.where('started_at >= ?', Time.zone.now.beginning_of_day).count
    @total_visits_this_week = public_visits.where('started_at >= ?', 1.week.ago).count
    @total_visits_this_month = public_visits.where('started_at >= ?', 1.month.ago).count
    @unique_visitors = public_visits.distinct.count(:visitor_token)
    @unique_visitors_this_month = public_visits.distinct.count(:visitor_token)
    
    # New vs Returning Visitors
    @new_visitors = public_visits.group(:visitor_token)
                                .having('COUNT(*) = 1')
                                .count
                                .length
    @returning_visitors = @unique_visitors_this_month - @new_visitors
    
    # Most viewed pages (public only) with events
    events = Ahoy::Event.where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                        .where('time >= ? AND time <= ?', @start_date, @end_date)
    
    @most_viewed_pages = events.group("properties->>'url'")
                               .order('count_all DESC')
                               .limit(15)
                               .count
    
    # Normalize page URLs for cleaner display
    @most_viewed_pages = @most_viewed_pages.transform_keys do |url|
      next 'Homepage' if url.nil? || url == '/' || url.empty?
      url.gsub(/^https?:\/\/[^\/]+/, '').presence || '/'
    end
    
    # Traffic Sources with categorization
    referrer_base = public_visits.where.not(referrer: nil)
    
    @traffic_by_source = {
      'Direct' => public_visits.where(referrer: nil).count,
      'Google' => referrer_base.where('referring_domain LIKE ?', '%google%').count,
      'Facebook' => referrer_base.where('referring_domain LIKE ?', '%facebook%').count,
      'Instagram' => referrer_base.where('referring_domain LIKE ?', '%instagram%').count,
      'Alte surse' => referrer_base.where.not('referring_domain LIKE ? OR referring_domain LIKE ? OR referring_domain LIKE ?',
                                               '%google%', '%facebook%', '%instagram%').count
    }
    
    # Top Referrers (detailed) - All referrers with percentages
    referrer_visits = public_visits.where.not(referrer: nil)
    @total_referrer_visits = referrer_visits.count
    @top_referrers = referrer_visits.group(:referring_domain)
                                    .order('count_all DESC')
                                    .count
    # Calculate percentages
    @top_referrers_with_percentage = @top_referrers.map do |domain, count|
      percentage = @total_referrer_visits > 0 ? ((count.to_f / @total_referrer_visits) * 100).round(2) : 0
      [domain, { count: count, percentage: percentage }]
    end.to_h
    
    # Browser statistics
    @browsers = public_visits.group(:browser)
                             .order('count_all DESC')
                             .limit(8)
                             .count
    
    # Operating Systems
    @operating_systems = public_visits.group(:os)
                                     .order('count_all DESC')
                                     .limit(8)
                                     .count
    
    # Device types
    @device_types = public_visits.group(:device_type)
                                 .order('count_all DESC')
                                 .count
    
    # Hourly Distribution (for selected period)
    @hourly_visits = (0..23).map do |hour|
      {
        hour: "#{hour}:00",
        count: public_visits.where('EXTRACT(HOUR FROM started_at) = ?', hour)
                           .count
      }
    end
    
    # Daily visits trend (for selected period)
    days_count = [(@end_date.to_date - @start_date.to_date).to_i, 90].min
    @daily_visits = (0..days_count).map do |i|
      date = i.days.ago(@end_date).beginning_of_day
      {
        date: date.strftime('%d %b'),
        count: public_visits.where('started_at >= ? AND started_at < ?', date, date + 1.day).count
      }
    end.reverse
    
    # Geographic Distribution (by city/region if available)
    @geographic_data = public_visits.where.not(city: [nil, ''])
                                   .group(:city)
                                   .order('count_all DESC')
                                   .limit(10)
                                   .count
    
    # User Engagement Metrics
    # Average visit duration (estimated from page views per visit)
    # Since Ahoy doesn't track duration directly, we set a default estimate
    @avg_visit_duration = 2.5 # Default estimate in minutes
    
    # Bounce Rate (visits with only one page view)
    total_visits_period = public_visits.count
    single_page_visits = events.group(:visit_id)
                               .having('COUNT(*) = 1')
                               .count
                               .length
    
    @bounce_rate = total_visits_period > 0 ? ((single_page_visits.to_f / total_visits_period) * 100).round(1) : 0
    
    # Pages per Visit
    total_events = events.count
    @pages_per_visit = total_visits_period > 0 ? (total_events.to_f / total_visits_period).round(2) : 0
    
    # Weekly Comparison (only if period allows)
    if (@end_date - @start_date) >= 2.weeks
      visits_this_week = public_visits.where('started_at >= ?', 1.week.ago(@end_date)).count
      visits_last_week = public_visits.where('started_at >= ? AND started_at < ?', 2.weeks.ago(@end_date), 1.week.ago(@end_date)).count
      @weekly_growth = visits_last_week > 0 ? (((visits_this_week - visits_last_week).to_f / visits_last_week) * 100).round(1) : 0
    else
      @weekly_growth = 0
    end
    
    # Top Exit Pages - All pages
    @top_exit_pages = events.group("properties->>'url'")
                            .order('count_all DESC')
                            .count
                            .transform_keys { |url| url&.gsub(/^https?:\/\/[^\/]+/, '')&.presence || '/' }
    
    # Top Entry Pages (landing pages)
    @top_entry_pages = public_visits.where.not(landing_page: [nil, ''])
                                    .group(:landing_page)
                                    .order('count_all DESC')
                                    .count
                                    .transform_keys { |url| url&.gsub(/^https?:\/\/[^\/]+/, '')&.presence || '/' }
    
    # Click Analytics - All clicks without limits
    click_events = events.where(name: 'click')
    
    @total_clicks = click_events.count
    
    # Most clicked links/buttons by destination - ALL
    @top_click_destinations = click_events
                                .group("properties->>'destination'")
                                .order('count_all DESC')
                                .count
                                .transform_keys { |dest| dest&.gsub(/^https?:\/\/[^\/]+/, '')&.presence || dest }
    
    # Most clicked elements by text - ALL
    @top_clicked_elements = click_events
                              .group("properties->>'text'")
                              .order('count_all DESC')
                              .count
    
    # Clicks by page (where users clicked from) - ALL
    @clicks_by_page = click_events
                        .group("properties->>'page'")
                        .order('count_all DESC')
                        .count
                        .transform_keys { |page| page&.presence || '/' }
    
    # Click types distribution
    @clicks_by_type = click_events
                        .group("properties->>'element_type'")
                        .count
    
    # Content statistics
    @members_with_bio = Member.joins(:rich_text_description).where.not(action_text_rich_texts: { body: [nil, ''] }).count rescue 0
    @members_with_photo = Member.joins(:photo_attachment).distinct.count rescue 0
    @services_per_specialty = MedicalService.group(:specialty_id).count
    @members_per_profession = Member.group(:profession_id).count
    @members_per_specialty = Member.where.not(specialty_id: nil).group(:specialty_id).count
    
    # Content completeness statistics
    @members_without_bio = Member.where.missing(:rich_text_description).count + 
                          Member.joins(:rich_text_description).where(action_text_rich_texts: { body: [nil, ''] }).count rescue Member.count - @members_with_bio
    @members_without_photo = Member.where.missing(:photo_attachment).count rescue Member.count - @members_with_photo
    @services_without_description = MedicalService.where.missing(:rich_text_description).count + 
                                   MedicalService.joins(:rich_text_description).where(action_text_rich_texts: { body: [nil, ''] }).count rescue 0
    
    # Specialty and profession coverage
    @specialties_with_members = Specialty.joins(:members).distinct.count
    @specialties_without_members = Specialty.count - @specialties_with_members
    @professions_with_members = Profession.joins(:members).distinct.count
    @professions_without_members = Profession.count - @professions_with_members
    
    # Services coverage
    @specialties_with_services = Specialty.joins(:medical_services).distinct.count
    @specialties_without_services = Specialty.count - @specialties_with_services
    
    # Time-based statistics (filtered by period)
    @members_created_this_month = Member.where('created_at >= ? AND created_at <= ?', @start_date, @end_date).count
    @services_created_this_month = MedicalService.where('created_at >= ? AND created_at <= ?', @start_date, @end_date).count
    @facts_updated_this_week = Fact.where('updated_at >= ? AND updated_at <= ?', @start_date, @end_date).count
    @users_created_this_month = User.where('created_at >= ? AND created_at <= ?', @start_date, @end_date).count
    
    # Recent activity
    @recent_members = Member.order(updated_at: :desc).limit(5)
    @recent_services = MedicalService.order(updated_at: :desc).limit(5)
    @recent_facts = Fact.order(updated_at: :desc).limit(5)
    @recent_users = User.order(updated_at: :desc).limit(5)
    
    # Database size metrics
    @total_records = Member.count + MedicalService.count + Specialty.count + 
                     Profession.count + Fact.count + User.count
    
    # Growth trends (last 6 months)
    @members_growth = (0..5).map do |i|
      date = i.months.ago.beginning_of_month
      {
        month: date.strftime('%b'),
        count: Member.where('created_at >= ? AND created_at < ?', date, date.end_of_month).count
      }
    end.reverse
    
    @services_growth = (0..5).map do |i|
      date = i.months.ago.beginning_of_month
      {
        month: date.strftime('%b'),
        count: MedicalService.where('created_at >= ? AND created_at < ?', date, date.end_of_month).count
      }
    end.reverse
    
    # Most active models (by updates)
    @most_updated_members = Member.order(updated_at: :desc).limit(10)
    @most_updated_services = MedicalService.order(updated_at: :desc).limit(10)
    
    # Completeness metrics
    @members_without_specialty = Member.where(specialty_id: nil).count
    @services_without_members = MedicalService.left_joins(:members).where(members: { id: nil }).count rescue 0
    
    # Top specialties by service count
    @top_specialties = Specialty.left_joins(:medical_services)
                                .group('specialties.id', 'specialties.name')
                                .select('specialties.*, COUNT(medical_services.id) as services_count')
                                .order('services_count DESC')
                                .limit(10)
    
    # Top professions by member count
    @top_professions = Profession.left_joins(:members)
                                 .group('professions.id', 'professions.name')
                                 .select('professions.*, COUNT(members.id) as members_count')
                                 .order('members_count DESC')
                                 .limit(10)
  end
  
  def edit_users
    @users = User.all.order(email: :asc)
  end

  def personal
    @member = Member.new()
    @members = Member.all.order(last_name: :asc)
    @professions = Profession.all.order(order: :asc)
    @specialties = Specialty.all.order(name: :asc)
  end
  
  def professions
    @profession = Profession.new()
    @professions = Profession.all.order(name: :asc)
  end
  
  def specialties
    @specialty = Specialty.new()
    @specialties = Specialty.all.order(name: :asc)
  end

  def medical_services
    @medical_service = MedicalService.new()
    @medical_services = MedicalService.order(name: :asc).to_a
    @selected_members = Member.includes([:medical_services]).select { |m| m.medical_services.count > 0}.to_a
    @specialties = Specialty.all.order(name: :asc)
  end

  def specialty_admin
    @medical_service = MedicalService.new()
    @specialty = Specialty.find_by!(slug: params[:id])
    
    # Order services: first by member (with member first), then by name
    @services_with_member = @specialty.medical_services
                                      .where.not(member_id: nil)
                                      .includes(:member)
                                      .order('members.last_name ASC, medical_services.name ASC')
    
    @services_without_member = @specialty.medical_services
                                         .where(member_id: nil)
                                         .order(name: :asc)
  end

  def info_pacient
    @fact = Fact.new()
    @facts = Fact.all.sort {|x, y| y.updated_at <=> x.updated_at}
  end
  
  def medicines_consumption
    @medicines_consumption = MedicinesConsumption.new
    @consumptions = MedicinesConsumption.all.order(year: :desc, month: :desc)
    @years = @consumptions.pluck(:year).uniq.sort.reverse
  end
  
  def audit
    @audit_logs = AuditLog.includes(:user).recent
    
    # Filter by date range if provided
    if params[:start_date].present?
      start_date = Date.parse(params[:start_date]).beginning_of_day
      @audit_logs = @audit_logs.where('audit_logs.created_at >= ?', start_date)
    end
    
    if params[:end_date].present?
      end_date = Date.parse(params[:end_date]).end_of_day
      @audit_logs = @audit_logs.where('audit_logs.created_at <= ?', end_date)
    end
    
    # Filter by action if provided
    @audit_logs = @audit_logs.by_action(params[:action_filter]) if params[:action_filter].present?
    
    # Filter by model type if provided
    @audit_logs = @audit_logs.by_type(params[:type_filter]) if params[:type_filter].present?
    
    # Filter by user if provided
    @audit_logs = @audit_logs.by_user(params[:user_filter]) if params[:user_filter].present?
    
    # Filter by controller if provided
    @audit_logs = @audit_logs.by_controller(params[:controller_filter]) if params[:controller_filter].present?
    
    # Filter by request method if provided
    @audit_logs = @audit_logs.by_request_method(params[:method_filter]) if params[:method_filter].present?
    
    # Exclude view actions if requested
    @audit_logs = @audit_logs.excluding_views if params[:exclude_views] == '1'
    
    # Paginate
    @audit_logs = @audit_logs.page(params[:page]).per(50)
    
    # Enhanced Statistics
    @total_logs = AuditLog.count
    @logs_today = AuditLog.today.count
    @logs_this_week = AuditLog.this_week.count
    @logs_this_month = AuditLog.this_month.count
    
    # Activity by action (including views)
    @activity_by_action = AuditLog.group(:action).count
    
    # Activity by model
    @activity_by_model = AuditLog.group(:auditable_type).count
    
    # Activity by controller
    @activity_by_controller = AuditLog.where.not(controller_name: nil)
                                      .group(:controller_name)
                                      .count
                                      .sort_by { |_, count| -count }
                                      .first(10)
    
    # Activity by request method
    @activity_by_method = AuditLog.where.not(request_method: nil)
                                  .group(:request_method)
                                  .count
    
    # Most active users with detailed stats
    @most_active_users = User.joins(:audit_logs)
                            .select('users.*, COUNT(audit_logs.id) as actions_count,
                                     MAX(audit_logs.created_at) as last_action_at')
                            .group('users.id')
                            .order('actions_count DESC')
                            .limit(10)
    
    # Recent significant actions (excluding views)
    @recent_significant = AuditLog.excluding_views
                                 .includes(:user)
                                 .recent
                                 .limit(20)
    
    # Recent activity timeline (all actions)
    @recent_activity = AuditLog.includes(:user).recent.limit(50)
    
    # Average response times
    @avg_duration = AuditLog.where.not(duration_ms: nil)
                           .where('created_at >= ?', 1.day.ago)
                           .average(:duration_ms)
                           &.round(0)
    
    # Most time-consuming actions
    @slowest_actions = AuditLog.where.not(duration_ms: nil)
                              .where('created_at >= ?', 1.day.ago)
                              .order(duration_ms: :desc)
                              .limit(10)
    
    # Error tracking (4xx, 5xx status codes)
    @error_logs = AuditLog.where('status_code >= ?', 400)
                         .where('created_at >= ?', 1.day.ago)
                         .count
    
    # Browser and device statistics
    @browser_stats = AuditLog.where('created_at >= ?', 7.days.ago)
                            .group_by { |log| log.browser_info }
                            .transform_values(&:count)
                            .sort_by { |_, count| -count }
    
    @device_stats = AuditLog.where('created_at >= ?', 7.days.ago)
                           .group_by { |log| log.device_info }
                           .transform_values(&:count)
                           .sort_by { |_, count| -count }
    
    # Available filters
    @available_actions = AuditLog.distinct.pluck(:action).compact.sort
    @available_types = AuditLog.distinct.pluck(:auditable_type).compact.sort
    @available_controllers = AuditLog.distinct.pluck(:controller_name).compact.sort
    @available_methods = AuditLog.distinct.pluck(:request_method).compact.sort
    @available_users = User.where(id: AuditLog.distinct.pluck(:user_id)).order(:email)
  end

  def test
    @profession = Profession.new()
    @professions = Profession.all.order(name: :asc)
    @specialty = Specialty.new()
    @specialties = Specialty.all.order(name: :asc)
  end

  private

  def calculate_start_date(period)
    case period
    when '7'
      7.days.ago
    when '30'
      30.days.ago
    when '90'
      90.days.ago
    when '180'
      180.days.ago
    when '365'
      365.days.ago
    when 'all'
      100.years.ago # Effectively all time
    else
      30.days.ago # Default to 30 days
    end
  end

end
