class AdminController < ApplicationController
  layout "dashboard"
  def dashboard
    @m = Member.new()
    @professions = Profession.all
    
    # Cache counts for dashboard stats
    @users_count = User.count
    @admin_count = User.where(admin: true).count
    @members_count = Member.count
    @professions_count = Profession.count
    @specialties_count = Specialty.count
    @services_count = MedicalService.count
    @facts_count = Fact.count
    @reviews_count = Review.count
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
    
    # Batch basic counts in one query per table
    @total_members = Member.count
    @total_services = MedicalService.count
    @total_specialties = Specialty.count
    @total_professions = Profession.count
    @total_facts = Fact.count
    @total_users = User.count
    
    # User role counts in single query
    user_counts = User.group(:admin, :god_mode).count
    @admin_users = user_counts.select { |k, _| k[0] == true }.values.sum
    @god_mode_users = user_counts.select { |k, _| k[1] == true }.values.sum
    
    # Base query for public visits - reuse throughout
    public_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                                .where('started_at >= ? AND started_at <= ?', @start_date, @end_date)
    
    # Visitor counts
    @total_visits = public_visits.count
    @unique_visitors = public_visits.distinct.count(:visitor_token)
    @unique_visitors_this_month = @unique_visitors
    
    # Time-based visit counts (separate queries for clarity and PostgreSQL compatibility)
    now = Time.zone.now
    @total_visits_today = public_visits.where('started_at >= ?', now.beginning_of_day).count
    @total_visits_this_week = public_visits.where('started_at >= ?', 1.week.ago).count
    @total_visits_this_month = public_visits.where('started_at >= ?', 1.month.ago).count
    
    # New vs Returning Visitors (limit data processed)
    visitor_counts = public_visits.group(:visitor_token).count
    @new_visitors = visitor_counts.count { |_, count| count == 1 }
    @returning_visitors = @unique_visitors_this_month - @new_visitors
    
    # Events base query
    events = Ahoy::Event.where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                        .where('time >= ? AND time <= ?', @start_date, @end_date)
    
    # Most viewed pages (LIMIT 15)
    @most_viewed_pages = events.group("properties->>'url'")
                               .order('count_all DESC')
                               .limit(15)
                               .count
                               .transform_keys { |url| normalize_url(url) }
    
    # Traffic Sources (optimized single query)
    traffic_data = public_visits.group(:referrer, :referring_domain).count
    @traffic_by_source = {
      'Direct' => traffic_data.select { |k, _| k[0].nil? }.values.sum,
      'Google' => traffic_data.select { |k, _| k[1]&.include?('google') }.values.sum,
      'Facebook' => traffic_data.select { |k, _| k[1]&.include?('facebook') }.values.sum,
      'Instagram' => traffic_data.select { |k, _| k[1]&.include?('instagram') }.values.sum
    }
    @traffic_by_source['Alte surse'] = @total_visits - @traffic_by_source.values.sum
    
    # Top Referrers (LIMIT 20)
    referrer_data = public_visits.where.not(referrer: nil)
                                 .group(:referring_domain)
                                 .order('count_all DESC')
                                 .limit(20)
                                 .count
    @total_referrer_visits = referrer_data.values.sum
    @top_referrers_with_percentage = referrer_data.transform_values do |count|
      { count: count, percentage: @total_referrer_visits > 0 ? ((count.to_f / @total_referrer_visits) * 100).round(2) : 0 }
    end
    
    # Browser, OS, Device (LIMIT 8)
    @browsers = public_visits.group(:browser).order('count_all DESC').limit(8).count
    @operating_systems = public_visits.group(:os).order('count_all DESC').limit(8).count
    @device_types = public_visits.group(:device_type).order('count_all DESC').count
    
    # Hourly Distribution (optimized single query)
    hourly_data = public_visits.group("EXTRACT(HOUR FROM started_at)").count
    @hourly_visits = (0..23).map { |hour| { hour: "#{hour}:00", count: hourly_data[hour.to_f] || 0 } }
    
    # Daily visits (optimized, limit to 30 days max for performance)
    days_count = [((@end_date.to_date - @start_date.to_date).to_i), 30].min
    daily_data = public_visits.group("DATE(started_at)").count
    @daily_visits = (0..days_count).map do |i|
      date = i.days.ago(@end_date).to_date
      { date: date.strftime('%d %b'), count: daily_data[date] || 0 }
    end.reverse
    
    # Geographic Distribution - Countries (LIMIT 15)
    @visitors_by_country = public_visits.where.not(country: [nil, ''])
                                        .group(:country)
                                        .order('count_all DESC')
                                        .limit(15)
                                        .count
    
    # Geographic Distribution - Romania by Region/County (LIMIT 20)
    @visitors_by_county = public_visits.where(country: ['Romania', 'RO'])
                                       .where.not(region: [nil, ''])
                                       .group(:region)
                                       .order('count_all DESC')
                                       .limit(20)
                                       .count
    
    # Geographic Distribution - Romania by City (LIMIT 20)
    @visitors_by_city_romania = public_visits.where(country: ['Romania', 'RO'])
                                             .where.not(city: [nil, ''])
                                             .group(:city)
                                             .order('count_all DESC')
                                             .limit(20)
                                             .count
    
    # Geographic Distribution - All Cities (Legacy, LIMIT 10)
    @geographic_data = public_visits.where.not(city: [nil, ''])
                                   .group(:city)
                                   .order('count_all DESC')
                                   .limit(10)
                                   .count
    
    # Engagement Metrics
    @avg_visit_duration = 2.5
    total_visits_period = @total_visits
    total_events = events.count
    single_page_visits = events.group(:visit_id).having('COUNT(*) = 1').count.length
    
    @bounce_rate = total_visits_period > 0 ? ((single_page_visits.to_f / total_visits_period) * 100).round(1) : 0
    @pages_per_visit = total_visits_period > 0 ? (total_events.to_f / total_visits_period).round(2) : 0
    
    # Weekly growth (only if needed)
    @weekly_growth = 0
    if (@end_date - @start_date) >= 2.weeks
      one_week_ago = 1.week.ago(@end_date)
      visits_this_week = public_visits.where('started_at >= ?', one_week_ago).count
      visits_last_week = public_visits.where('started_at < ?', one_week_ago).count
      @weekly_growth = visits_last_week > 0 ? (((visits_this_week - visits_last_week).to_f / visits_last_week) * 100).round(1) : 0
    end
    
    # Entry/Exit pages (LIMIT 10)
    @top_entry_pages = public_visits.where.not(landing_page: [nil, ''])
                                    .group(:landing_page)
                                    .order('count_all DESC')
                                    .limit(10)
                                    .count
                                    .transform_keys { |url| normalize_url(url) }
    
    @top_exit_pages = events.group("properties->>'url'")
                            .order('count_all DESC')
                            .limit(10)
                            .count
                            .transform_keys { |url| normalize_url(url) }
    
    # Click Analytics (LIMIT 10 each)
    click_events = events.where(name: 'click')
    @total_clicks = click_events.count
    
    @top_click_destinations = click_events.group("properties->>'destination'")
                                          .order('count_all DESC')
                                          .limit(10)
                                          .count
                                          .transform_keys { |dest| dest&.gsub(/^https?:\/\/[^\/]+/, '')&.presence || dest }
    
    @top_clicked_elements = click_events.group("properties->>'text'")
                                        .order('count_all DESC')
                                        .limit(10)
                                        .count
    
    @clicks_by_page = click_events.group("properties->>'page'")
                                  .order('count_all DESC')
                                  .limit(10)
                                  .count
                                  .transform_keys { |page| page&.presence || '/' }
    
    @clicks_by_type = click_events.group("properties->>'element_type'").count
    
    # Content statistics (optimized with calculations instead of separate counts)
    @members_with_bio = Member.joins(:rich_text_description).where.not(action_text_rich_texts: { body: [nil, ''] }).count rescue 0
    @members_without_bio = @total_members - @members_with_bio
    
    @members_with_photo = Member.joins(:photo_attachment).distinct.count rescue 0
    @members_without_photo = @total_members - @members_with_photo
    
    @services_per_specialty = MedicalService.group(:specialty_id).count
    @members_per_profession = Member.group(:profession_id).count
    @members_per_specialty = Member.where.not(specialty_id: nil).group(:specialty_id).count
    
    @services_without_description = @total_services - (MedicalService.joins(:rich_text_description).where.not(action_text_rich_texts: { body: [nil, ''] }).count rescue 0)
    
    # Coverage metrics (use existing counts)
    specialty_member_counts = @members_per_specialty.keys.uniq.size
    @specialties_with_members = specialty_member_counts
    @specialties_without_members = @total_specialties - @specialties_with_members
    
    profession_member_counts = @members_per_profession.keys.uniq.size
    @professions_with_members = profession_member_counts
    @professions_without_members = @total_professions - @professions_with_members
    
    @specialties_with_services = @services_per_specialty.keys.uniq.size
    @specialties_without_services = @total_specialties - @specialties_with_services
    
    # Time-based statistics
    @members_created_this_month = Member.where('created_at >= ? AND created_at <= ?', @start_date, @end_date).count
    @services_created_this_month = MedicalService.where('created_at >= ? AND created_at <= ?', @start_date, @end_date).count
    @facts_updated_this_week = Fact.where('updated_at >= ? AND updated_at <= ?', @start_date, @end_date).count
    @users_created_this_month = User.where('created_at >= ? AND created_at <= ?', @start_date, @end_date).count
    
    # Recent activity (eager load minimal data)
    @recent_members = Member.select(:id, :first_name, :last_name, :updated_at).order(updated_at: :desc).limit(5)
    @recent_services = MedicalService.select(:id, :name, :updated_at).order(updated_at: :desc).limit(5)
    @recent_facts = Fact.select(:id, :title, :updated_at).order(updated_at: :desc).limit(5)
    @recent_users = User.select(:id, :email, :updated_at).order(updated_at: :desc).limit(5)
    
    # Database metrics (use cached counts)
    @total_records = @total_members + @total_services + @total_specialties + @total_professions + @total_facts + @total_users
    
    # Growth trends (optimized - single query per model)
    six_months_ago = 6.months.ago.beginning_of_month
    member_growth_data = Member.where('created_at >= ?', six_months_ago)
                               .group("DATE_TRUNC('month', created_at)")
                               .count
    
    @members_growth = (0..5).map do |i|
      date = i.months.ago.beginning_of_month
      { month: date.strftime('%b'), count: member_growth_data[date] || 0 }
    end.reverse
    
    service_growth_data = MedicalService.where('created_at >= ?', six_months_ago)
                                        .group("DATE_TRUNC('month', created_at)")
                                        .count
    
    @services_growth = (0..5).map do |i|
      date = i.months.ago.beginning_of_month
      { month: date.strftime('%b'), count: service_growth_data[date] || 0 }
    end.reverse
    
    # Most updated (LIMIT 10, minimal fields)
    @most_updated_members = Member.select(:id, :first_name, :last_name, :updated_at).order(updated_at: :desc).limit(10)
    @most_updated_services = MedicalService.select(:id, :name, :updated_at).order(updated_at: :desc).limit(10)
    
    # Completeness metrics
    @members_without_specialty = Member.where(specialty_id: nil).count
    @services_without_members = MedicalService.left_joins(:members).where(members: { id: nil }).distinct.count rescue 0
    
    # Top specialties and professions (already grouped data exists)
    @top_specialties = Specialty.left_joins(:medical_services)
                                .group('specialties.id', 'specialties.name')
                                .select('specialties.id, specialties.name, COUNT(medical_services.id) as services_count')
                                .order('services_count DESC')
                                .limit(10)
    
    @top_professions = Profession.left_joins(:members)
                                 .group('professions.id', 'professions.name')
                                 .select('professions.id, professions.name, COUNT(members.id) as members_count')
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
    @medical_services = MedicalService.order(name: :asc)
    @selected_members = Member.joins(:medical_services).distinct.includes(:medical_services).order(last_name: :asc)
    @specialties = Specialty.includes(:medical_services).order(name: :asc)
  end

  def specialty_admin
    @medical_service = MedicalService.new()
    @specialty = Specialty.includes(:medical_services).find_by!(slug: params[:id])
    @all_specialties = Specialty.order(name: :asc)
    
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
    @facts = Fact.all.order(updated_at: :desc)
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
    
    # Browser and device statistics (optimized to avoid loading all records)
    week_logs = AuditLog.where('created_at >= ?', 7.days.ago).select(:user_agent).to_a
    
    @browser_stats = week_logs.group_by { |log| log.browser_info }
                              .transform_values(&:count)
                              .sort_by { |_, count| -count }
    
    @device_stats = week_logs.group_by { |log| log.device_info }
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
  
  def normalize_url(url)
    return 'Homepage' if url.nil? || url == '/' || url.empty?
    url.gsub(/^https?:\/\/[^\/]+/, '').presence || '/'
  end

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
