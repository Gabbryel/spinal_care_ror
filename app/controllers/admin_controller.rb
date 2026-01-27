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
    # Period filter setup with new presets
    @period = params[:period] || '30'
    @custom_start_date = params[:custom_start_date]
    @custom_end_date = params[:custom_end_date]
    
    # Calculate date range based on period
    if @period == 'custom' && @custom_start_date.present? && @custom_end_date.present?
      @start_date = Time.zone.parse(@custom_start_date).beginning_of_day
      @end_date = Time.zone.parse(@custom_end_date).end_of_day
    else
      @end_date = Time.zone.now
      @start_date = case @period
                    when 'today' then @end_date.beginning_of_day
                    when 'week' then 1.week.ago(@end_date)
                    when 'month' then 1.month.ago(@end_date)
                    when '7' then 7.days.ago(@end_date)
                    when '30' then 30.days.ago(@end_date)
                    when '90' then 90.days.ago(@end_date)
                    when 'all' then 100.years.ago
                    else 30.days.ago(@end_date)
                    end
    end
    
    # PHASE 1: HERO KPIs ONLY - Optimize for <1s load
    # Base query for public visits
    public_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                                .where('started_at >= ? AND started_at <= ?', @start_date, @end_date)
    
    # Critical metrics
    @total_visitors = public_visits.count
    @unique_visitors = public_visits.distinct.count(:visitor_token)
    days_in_period = ((@end_date - @start_date) / 1.day).ceil
    @daily_average = days_in_period > 0 ? (@total_visitors / days_in_period).round : 0
    
    # Previous period comparison (single efficient query)
    prev_start = @start_date - (@end_date - @start_date)
    prev_end = @start_date
    prev_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                             .where('started_at >= ? AND started_at < ?', prev_start, prev_end)
    prev_count = prev_visits.count
    @visitors_change_pct = prev_count > 0 ? (((@total_visitors - prev_count).to_f / prev_count) * 100).round(1) : 0
    
    prev_unique = prev_visits.distinct.count(:visitor_token)
    @unique_change_pct = prev_unique > 0 ? (((@unique_visitors - prev_unique).to_f / prev_unique) * 100).round(1) : 0
    
    prev_daily = prev_count / days_in_period.to_f
    @daily_change_pct = prev_daily > 0 ? (((@daily_average - prev_daily) / prev_daily) * 100).round(1) : 0
    
    # Top 3 metrics (LIMIT 1 for performance)
    @top_location = public_visits.where.not(city: [nil, ''])
                                  .group(:city)
                                  .order('count_all DESC')
                                  .limit(1)
                                  .count
                                  .first
    
    # Calculate trend for top location (compare current count vs previous period count for same location)
    if @top_location
      prev_location_count = prev_visits.where(city: @top_location[0]).count
      @location_change_pct = prev_location_count > 0 ? (((@top_location[1] - prev_location_count).to_f / prev_location_count) * 100).round(1) : 0
    else
      @location_change_pct = 0
    end
    
    @top_source = public_visits.group(:referring_domain)
                                .order('count_all DESC')
                                .limit(1)
                                .count
                                .first
    @top_source = @top_source ? [@top_source[0] || 'Direct', @top_source[1]] : ['Direct', @total_visitors]
    
    # Calculate trend for top source
    prev_source_count = prev_visits.where(referring_domain: @top_source[0]).count
    @source_change_pct = prev_source_count > 0 ? (((@top_source[1] - prev_source_count).to_f / prev_source_count) * 100).round(1) : 0
    
    events = Ahoy::Event.where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                        .where('time >= ? AND time <= ?', @start_date, @end_date)
    
    @top_page = events.group(Arel.sql("properties->>'url'"))
                     .order('count_all DESC')
                     .limit(1)
                     .count
                     .first
    @top_page = @top_page ? [normalize_url(@top_page[0]), @top_page[1]] : ['/', 0]
    
    # Calculate trend for top page
    prev_events = Ahoy::Event.where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                              .where('time >= ? AND time < ?', prev_start, @start_date)
    prev_page_count = prev_events.where("properties->>'url' = ?", @top_page[0]).count
    @page_change_pct = prev_page_count > 0 ? (((@top_page[1] - prev_page_count).to_f / prev_page_count) * 100).round(1) : 0
    
    # Store base queries for lazy-loaded sections
    @public_visits_query = public_visits
    @events_query = events
  end
  
  # PHASE 2: Lazy-loaded sections
  def analytics_daily_chart
    start_date = calculate_period_dates[:start_date]
    end_date = calculate_period_dates[:end_date]
    
    public_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                                .where('started_at >= ? AND started_at <= ?', start_date, end_date)
    
    days_count = ((end_date.to_date - start_date.to_date).to_i).abs
    daily_data = public_visits.group("DATE(started_at)").count
    
    daily_visits = (0..days_count).map do |i|
      date = (start_date.to_date + i.days)
      { date: date, label: date.strftime('%d %b'), count: daily_data[date] || 0 }
    end
    
    @daily_labels = daily_visits.map { |d| d[:label] }
    @daily_data = daily_visits.map { |d| d[:count] }
    
    render partial: 'admin/analytics/daily_chart'
  end
  
  def analytics_geography
    start_date = calculate_period_dates[:start_date]
    end_date = calculate_period_dates[:end_date]
    
    events = Ahoy::Event.where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                        .where('time >= ? AND time <= ?', start_date, end_date)
    
    public_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                                .where('started_at >= ? AND started_at <= ?', start_date, end_date)
    
    @total_visitors = public_visits.count
    @unique_visitors = public_visits.distinct.count(:visitor_token)
    
    @top_cities = public_visits.where.not(city: [nil, ''])
                                    .group(:city)
                                    .order('count_all DESC')
                                    .limit(20)
                                    .count
    
    @top_exit_pages = events.group("properties->>'url'")
                            .order('count_all DESC')
                            .limit(10)
                            .count
                            .transform_keys { |url| normalize_url(url) }
    
    # Click Analytics (LIMIT 10 each)
    click_events = events.where(name: ['click', '$click'])
    @total_clicks = click_events.count
    
    # Use 'url' field for automatic $click events (most common)
    @top_click_destinations = click_events.where("properties->>'url' IS NOT NULL AND properties->>'url' != ''")
                                          .group("properties->>'url'")
                                          .order('count_all DESC')
                                          .limit(10)
                                          .count
                                          .transform_keys { |dest| normalize_url(dest) }
    
    # Use 'name' field for link text from automatic tracking, fallback to 'text' for custom events
    @top_clicked_elements = click_events.where("(properties->>'name' IS NOT NULL AND properties->>'name' != '') OR (properties->>'text' IS NOT NULL AND properties->>'text' != '')")
                                        .group(Arel.sql("COALESCE(properties->>'name', properties->>'text')"))
                                        .order('count_all DESC')
                                        .limit(10)
                                        .count
    
    @top_countries = public_visits.where.not(country: [nil, ''])
                                        .group(:country)
                                        .order('count_all DESC')
                                        .limit(10)
                                        .count
    
    render partial: 'admin/analytics/geography'
  end
  
  def analytics_sources
    start_date = calculate_period_dates[:start_date]
    end_date = calculate_period_dates[:end_date]
    
    public_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                                .where('started_at >= ? AND started_at <= ?', start_date, end_date)
    
    @total_visitors = public_visits.count
    @unique_visitors = public_visits.distinct.count(:visitor_token)
    
    traffic_data = public_visits.group(:referrer, :referring_domain).count
    @traffic_sources = {
      'Direct' => traffic_data.select { |k, _| k[0].nil? }.values.sum,
      'Google' => traffic_data.select { |k, _| k[1]&.include?('google') }.values.sum,
      'Facebook' => traffic_data.select { |k, _| k[1]&.include?('facebook') }.values.sum,
      'Instagram' => traffic_data.select { |k, _| k[1]&.include?('instagram') }.values.sum
    }
    total = public_visits.count
    @traffic_sources['Alte surse'] = total - @traffic_sources.values.sum
    
    @top_referrers = public_visits.where.not(referring_domain: nil)
                                  .group(:referring_domain)
                                  .order('count_all DESC')
                                  .limit(15)
                                  .count
    
    render partial: 'admin/analytics/sources'
  end
  
  def analytics_pages
    start_date = calculate_period_dates[:start_date]
    end_date = calculate_period_dates[:end_date]
    
    events = Ahoy::Event.where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                        .where('time >= ? AND time <= ?', start_date, end_date)
    
    page_events = events.group(Arel.sql("properties->>'url'"))
                        .order('count_all DESC')
                        .limit(20)
                        .count
    
    @most_viewed_pages = page_events.transform_keys { |url| normalize_url(url) }
    @total_page_views = page_events.values.sum
    @unique_pages_count = page_events.keys.count
    
    public_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                                .where('started_at >= ? AND started_at <= ?', start_date, end_date)
    
    @top_entry_pages = public_visits.where.not(landing_page: [nil, ''])
                                    .group(:landing_page)
                                    .order('count_all DESC')
                                    .limit(15)
                                    .count
                                    .transform_keys { |url| normalize_url(url) }
    
    @unique_visitors = public_visits.distinct.count(:visitor_token)
    
    render partial: 'admin/analytics/pages'
  end
  
  def analytics_user_journey
    start_date = calculate_period_dates[:start_date]
    end_date = calculate_period_dates[:end_date]
    
    public_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                                .where('started_at >= ? AND started_at <= ?', start_date, end_date)
    
    @total_visitors = public_visits.count
    @unique_visitors = public_visits.distinct.count(:visitor_token)
    
    # Filter meaningful clicks (exclude GDPR, external, UI noise)
    meaningful_clicks = Ahoy::Event
      .where(name: '$click')
      .where("properties->>'url' NOT LIKE '%privacy%'")
      .where("properties->>'url' NOT LIKE '%cookie%'")
      .where("properties->>'url' NOT LIKE '%gdpr%'")
      .where("properties->>'name' NOT ILIKE '%Accept%Cookie%' OR properties->>'name' IS NULL")
      .where("properties->>'name' NOT ILIKE '%Decline%' OR properties->>'name' IS NULL")
      .where("properties->>'name' NOT ILIKE '%Close%' OR properties->>'name' IS NULL")
      .where('time >= ? AND time <= ?', start_date, end_date)
    
    # User journey sequences
    @user_journeys = meaningful_clicks
      .select(:visit_id, Arel.sql("STRING_AGG(properties->>'url', ' → ' ORDER BY time) as path"))
      .group(:visit_id)
      .having('COUNT(*) > 1')
      .limit(100)
      .map { |j| j.path }
      .group_by(&:itself)
      .transform_values(&:count)
      .sort_by { |_, count| -count }
      .first(10)
    
    # Top navigation clicks (internal only)
    @top_navigation_clicks = meaningful_clicks
      .where("properties->>'url' LIKE '/echipa%' 
              OR properties->>'url' LIKE '/servicii%' 
              OR properties->>'url' LIKE '/specialitati%'
              OR properties->>'url' LIKE '/informatii%'")
      .group(Arel.sql("properties->>'url'"))
      .order('count_all DESC')
      .limit(15)
      .count
      .transform_keys { |url| normalize_url(url) }
    
    # Conversion clicks
    @conversion_clicks = meaningful_clicks
      .where("properties->>'name' ILIKE '%contact%' 
              OR properties->>'name' ILIKE '%programare%'
              OR properties->>'name' ILIKE '%apel%'
              OR properties->>'url' LIKE 'tel:%'
              OR properties->>'url' LIKE 'mailto:%'")
      .group(Arel.sql("properties->>'name'"))
      .order('count_all DESC')
      .limit(10)
      .count
    
    # Set view variables
    @navigation_clicks = @top_navigation_clicks.map { |url, count| { 'name' => url, 'landing_page' => url, 'click_count' => count } }
    @total_clicks = meaningful_clicks.count
    @conversions_count = @conversion_clicks&.values&.sum || 0
    @user_journey_paths = @user_journeys&.map { |path, count| { 'pages' => path.split(' → '), 'count' => count } } || []
    
    render partial: 'admin/analytics/user_journey'
  end
  
  def analytics_content
    start_date = calculate_period_dates[:start_date]
    end_date = calculate_period_dates[:end_date]
    
    # Get all relevant events (both page views and clicks)
    events = Ahoy::Event.where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                        .where('time >= ? AND time <= ?', start_date, end_date)
    
    # Debug logging for production
    Rails.logger.info "Analytics Content - Total events: #{events.count}"
    Rails.logger.info "Analytics Content - Date range: #{start_date} to #{end_date}"
    
    # Top doctors by profile views (all event types with /echipa/ URLs)
    doctor_events = events.where("properties->>'url' LIKE ?", '/echipa/%')
                         .where("properties->>'url' NOT LIKE ?", '%/echipa#%')  # Exclude anchor links
                         .group(Arel.sql("properties->>'url'"))
                         .order('count_all DESC')
                         .limit(10)
                         .count
    
    Rails.logger.info "Analytics Content - Doctor events: #{doctor_events.inspect}"
    
    @top_doctors = doctor_events.map do |url, count|
      slug = url.split('/').last&.split('?')&.first&.split('#')&.first  # Clean URL parameters and fragments
      next if slug.blank?
      member = Member.find_by(slug: slug) || Member.find_by("first_name || '-' || last_name = ?", slug)
      [member&.name || slug, count]
    end.compact
    @total_doctor_views = doctor_events.values.sum
    
    # Top specialties
    specialty_events = events.where("properties->>'url' LIKE ?", '/specialitati%')
                            .where("properties->>'url' NOT LIKE ?", '%/specialitati#%')
                            .group(Arel.sql("properties->>'url'"))
                            .order('count_all DESC')
                            .limit(10)
                            .count
    
    Rails.logger.info "Analytics Content - Specialty events: #{specialty_events.inspect}"
    
    @top_specialties = specialty_events.map do |url, count|
      slug = url.split('/').last&.split('?')&.first&.split('#')&.first
      next if slug.blank?
      specialty = Specialty.find_by(slug: slug)
      [specialty&.name || slug, count]
    end.compact
    @total_specialty_views = specialty_events.values.sum
    
    # Top services
    service_events = events.where("properties->>'url' LIKE ?", '/servicii%')
                          .where("properties->>'url' NOT LIKE ?", '%/servicii#%')
                          .group(Arel.sql("properties->>'url'"))
                          .order('count_all DESC')
                          .limit(10)
                          .count
    
    Rails.logger.info "Analytics Content - Service events: #{service_events.inspect}"
    
    @top_services = service_events.map do |url, count|
      slug = url.split('/').last&.split('?')&.first&.split('#')&.first
      next if slug.blank?
      service = MedicalService.find_by(slug: slug)
      [service&.name || slug, count]
    end.compact
    @total_service_views = service_events.values.sum
    
    render partial: 'admin/analytics/content'
  end

  def analytics_debug
    start_date = calculate_period_dates[:start_date]
    end_date = calculate_period_dates[:end_date]

    # Database Statistics
    @debug_data = {
      database_stats: {
        total_visits: Ahoy::Visit.count,
        total_events: Ahoy::Event.count,
        visits_in_period: Ahoy::Visit.where('started_at >= ? AND started_at <= ?', start_date, end_date).count,
        events_in_period: Ahoy::Event.where('time >= ? AND time <= ?', start_date, end_date).count
      },
      
      # Geography Data
      geography: {
        visits_with_city: Ahoy::Visit.where.not(city: [nil, '']).count,
        visits_with_country: Ahoy::Visit.where.not(country: [nil, '']).count,
        unique_cities: Ahoy::Visit.where.not(city: [nil, '']).distinct.pluck(:city).count,
        unique_countries: Ahoy::Visit.where.not(country: [nil, '']).distinct.pluck(:country).count,
        sample_cities: Ahoy::Visit.where.not(city: [nil, '']).limit(10).pluck(:city, :country),
        top_cities_query: Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                                     .where('started_at >= ? AND started_at <= ?', start_date, end_date)
                                     .where.not(city: [nil, ''])
                                     .group(:city, :country)
                                     .order('count_all DESC')
                                     .limit(10)
                                     .count
      },
      
      # Click Events Data
      clicks: {
        total_click_events: Ahoy::Event.where(name: ['$click', 'click']).count,
        click_events_in_period: Ahoy::Event.where(name: ['$click', 'click'])
                                           .where('time >= ? AND time <= ?', start_date, end_date).count,
        events_with_url: Ahoy::Event.where("properties->>'url' IS NOT NULL")
                                    .where("properties->>'url' != ''").count,
        events_with_name: Ahoy::Event.where("properties->>'name' IS NOT NULL")
                                     .where("properties->>'name' != ''").count,
        sample_click_events: Ahoy::Event.where(name: ['$click', 'click'])
                                        .limit(5)
                                        .pluck(:name, :properties),
        event_names: Ahoy::Event.group(:name).count,
        sample_properties: Ahoy::Event.where.not(properties: {}).limit(10).pluck(:name, :properties)
      },
      
      # Performance/Page Views
      performance: {
        view_events: Ahoy::Event.where(name: '$view').count,
        view_events_in_period: Ahoy::Event.where(name: '$view')
                                          .where('time >= ? AND time <= ?', start_date, end_date).count,
        top_urls: Ahoy::Event.where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                             .where('time >= ? AND time <= ?', start_date, end_date)
                             .group(Arel.sql("properties->>'url'"))
                             .order('count_all DESC')
                             .limit(10)
                             .count,
        sample_view_events: Ahoy::Event.where(name: '$view')
                                       .limit(5)
                                       .pluck(:time, :properties)
      },
      
      # Date Range Info
      period_info: {
        start_date: start_date,
        end_date: end_date,
        days_in_period: ((end_date - start_date) / 1.day).ceil,
        current_period: params[:period] || '30'
      }
    }

    render partial: 'admin/analytics/debug'
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
  
  def calculate_period_dates
    period = params[:period] || '30'
    custom_start = params[:custom_start_date]
    custom_end = params[:custom_end_date]
    
    if period == 'custom' && custom_start.present? && custom_end.present?
      start_date = Time.zone.parse(custom_start).beginning_of_day
      end_date = Time.zone.parse(custom_end).end_of_day
    else
      end_date = Time.zone.now
      start_date = case period
                   when 'today' then end_date.beginning_of_day
                   when 'week' then 1.week.ago(end_date)
                   when 'month' then 1.month.ago(end_date)
                   when '7' then 7.days.ago(end_date)
                   when '30' then 30.days.ago(end_date)
                   when '90' then 90.days.ago(end_date)
                   when 'all' then 100.years.ago
                   else 30.days.ago(end_date)
                   end
    end
    
    { start_date: start_date, end_date: end_date }
  end
  
  def normalize_url(url)
    return 'Homepage' if url.nil? || url == '/' || url.empty?
    url.gsub(/^https?:\/\/[^\/]+/, '').presence || '/'
  end

  def calculate_start_date(period)
    case period
    when 'today'
      Time.zone.now.beginning_of_day
    when 'week'
      1.week.ago
    when 'month'
      1.month.ago
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
      100.years.ago
    else
      30.days.ago
    end
  end

end
