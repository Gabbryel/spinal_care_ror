class AdminController < ApplicationController
  include AnalyticsFilterHelper
  
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
    @filter_bots = params[:filter_bots] != 'false' # Default: filter bots
    @filter_geography = params[:filter_geography] == 'true' # Default: show all countries
    
    # Calculate date range based on period
    dates = calculate_period_dates
    @start_date = dates[:start_date]
    @end_date = dates[:end_date]
    
    # PHASE 1: HERO KPIs ONLY - Optimize for <1s load
    # Base query for public visits (with bot and geo filtering)
    base_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                              .where('started_at >= ? AND started_at <= ?', @start_date, @end_date)
    
    public_visits = apply_analytics_filters(base_visits, 
                                           include_bots: !@filter_bots,
                                           relevant_countries_only: @filter_geography)
    
    # Critical metrics
    @total_visitors = public_visits.count
    @unique_visitors = public_visits.distinct.count(:visitor_token)
    days_in_period = ((@end_date - @start_date) / 1.day).ceil
    @daily_average = days_in_period > 0 ? (@total_visitors / days_in_period).round : 0
    
    # Previous period comparison (single efficient query)
    prev_start = @start_date - (@end_date - @start_date)
    prev_end = @start_date
    prev_base = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                           .where('started_at >= ? AND started_at < ?', prev_start, prev_end)
    prev_visits = apply_analytics_filters(prev_base,
                                         include_bots: !@filter_bots,
                                         relevant_countries_only: @filter_geography)
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
    dates = calculate_period_dates
    @start_date = dates[:start_date]
    @end_date = dates[:end_date]
    filter_bots = params[:filter_bots] != 'false'
    filter_geography = params[:filter_geography] == 'true'
    
    base_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                              .where('started_at >= ? AND started_at <= ?', @start_date, @end_date)
    public_visits = apply_analytics_filters(base_visits, include_bots: !filter_bots, relevant_countries_only: filter_geography)
    
    # Calculate number of days in period (inclusive)
    days_count = ((@end_date.to_date - @start_date.to_date).to_i + 1)
    daily_data = public_visits.group("DATE(started_at)").count
    
    daily_visits = (0...days_count).map do |i|
      date = (@start_date.to_date + i.days)
      { date: date, label: date.strftime('%d %b'), count: daily_data[date] || 0 }
    end
    
    @daily_labels = daily_visits.map { |d| d[:label] }
    @daily_data = daily_visits.map { |d| d[:count] }
    
    render partial: 'admin/analytics/daily_chart'
  end
  
  def analytics_geography
    dates = calculate_period_dates
    start_date = dates[:start_date]
    end_date = dates[:end_date]
    filter_bots = params[:filter_bots] != 'false'
    filter_geography = params[:filter_geography] == 'true'
    
    # Apply bot and geography filters
    base_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                              .where('started_at >= ? AND started_at <= ?', start_date, end_date)
    public_visits = apply_analytics_filters(base_visits, include_bots: !filter_bots, relevant_countries_only: filter_geography)
    
    # Get filtered visit IDs for event filtering
    filtered_visit_ids = public_visits.pluck(:id)
    
    events = Ahoy::Event.where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                        .where('time >= ? AND time <= ?', start_date, end_date)
                        .where(visit_id: filtered_visit_ids)
    
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
    dates = calculate_period_dates
    start_date = dates[:start_date]
    end_date = dates[:end_date]
    filter_bots = params[:filter_bots] != 'false'
    filter_geography = params[:filter_geography] == 'true'
    
    base_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                              .where('started_at >= ? AND started_at <= ?', start_date, end_date)
    public_visits = apply_analytics_filters(base_visits, include_bots: !filter_bots, relevant_countries_only: filter_geography)
    
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
    dates = calculate_period_dates
    start_date = dates[:start_date]
    end_date = dates[:end_date]
    filter_bots = params[:filter_bots] != 'false'
    filter_geography = params[:filter_geography] == 'true'
    
    # Get filtered visit IDs
    base_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                              .where('started_at >= ? AND started_at <= ?', start_date, end_date)
    filtered_visits = apply_analytics_filters(base_visits, include_bots: !filter_bots, relevant_countries_only: filter_geography)
    filtered_visit_ids = filtered_visits.pluck(:id)
    
    events = Ahoy::Event.where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                        .where('time >= ? AND time <= ?', start_date, end_date)
                        .where(visit_id: filtered_visit_ids)
    
    page_events = events.group(Arel.sql("properties->>'url'"))
                        .order('count_all DESC')
                        .limit(20)
                        .count
    
    @most_viewed_pages = page_events.transform_keys { |url| normalize_url(url) }
    @total_page_views = page_events.values.sum
    @unique_pages_count = page_events.keys.count
    
    # Use the already filtered visits for entry pages
    @top_entry_pages = filtered_visits.where.not(landing_page: [nil, ''])
                                      .group(:landing_page)
                                      .order('count_all DESC')
                                      .limit(15)
                                      .count
                                      .transform_keys { |url| normalize_url(url) }
    
    @unique_visitors = filtered_visits.distinct.count(:visitor_token)
    
    render partial: 'admin/analytics/pages'
  end
  
  def edit_users
    @users = User.all.order(email: :asc)
  end

  def analytics_hourly
    dates = calculate_period_dates
    start_date = dates[:start_date]
    end_date = dates[:end_date]
    filter_bots = params[:filter_bots] != 'false'
    filter_geography = params[:filter_geography] == 'true'
    
    base_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                              .where('started_at >= ? AND started_at <= ?', start_date, end_date)
    public_visits = apply_analytics_filters(base_visits, include_bots: !filter_bots, relevant_countries_only: filter_geography)
    
    # Group visits by hour of the day (0-23)
    hourly_data = public_visits
      .group(Arel.sql("EXTRACT(HOUR FROM started_at)::integer"))
      .order(Arel.sql("EXTRACT(HOUR FROM started_at)::integer"))
      .count
    
    # Fill in missing hours with 0
    @hourly_visits = (0..23).map do |hour|
      {
        hour: hour,
        label: "#{hour.to_s.rjust(2, '0')}:00",
        count: hourly_data[hour] || 0
      }
    end
    
    @total_visits = public_visits.count
    @peak_hour = @hourly_visits.max_by { |h| h[:count] }
    @quiet_hour = @hourly_visits.min_by { |h| h[:count] }
    
    render partial: 'admin/analytics/hourly'
  end

  def analytics_geo_sources
    dates = calculate_period_dates
    start_date = dates[:start_date]
    end_date = dates[:end_date]
    filter_bots = params[:filter_bots] != 'false'
    filter_geography = params[:filter_geography] == 'true'

    base_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                              .where('started_at >= ? AND started_at <= ?', start_date, end_date)
    public_visits = apply_analytics_filters(base_visits, include_bots: !filter_bots, relevant_countries_only: filter_geography)
    # Traffic source (referrer domain or 'Direct') + City/Country
    @geo_sources = public_visits
      .where.not(city: [nil, ''])
      .select(:referring_domain, :city, :country, 'COUNT(*) as visit_count')
      .group(:referring_domain, :city, :country)
      .order('visit_count DESC')
      .limit(50)
      .map do |row|
        {
          source: row.referring_domain.present? ? row.referring_domain : 'Direct',
          city: row.city,
          country: row.country,
          visits: row.visit_count
        }
      end
    
    # Top sources overall
    @top_sources = public_visits
      .select(:referring_domain, 'COUNT(*) as visit_count')
      .group(:referring_domain)
      .order('visit_count DESC')
      .limit(10)
      .map { |row| { source: row.referring_domain.present? ? row.referring_domain : 'Direct', visits: row.visit_count } }
    
    # Top locations overall
    @top_locations = public_visits
      .where.not(city: [nil, ''])
      .select(:city, :country, 'COUNT(*) as visit_count')
      .group(:city, :country)
      .order('visit_count DESC')
      .limit(10)
      .map { |row| { city: row.city, country: row.country, visits: row.visit_count } }
    
    @total_geo_visits = public_visits.where.not(city: [nil, '']).count
    
    render partial: 'admin/analytics/geo_sources'
  end

  def analytics_bot_traffic
    dates = calculate_period_dates
    start_date = dates[:start_date]
    end_date = dates[:end_date]

    base_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                              .where('started_at >= ? AND started_at <= ?', start_date, end_date)

    # Bot visits based on user agent
    bot_user_agent_visits = base_visits.where(
      "user_agent ~* ?",
      BOT_PATTERNS.map(&:source).join('|')
    )

    # Visits from bot-heavy countries
    bot_country_visits = base_visits.where(country: BOT_COUNTRIES)

    # Combined: visits that are EITHER bots OR from bot countries
    all_bot_visits = base_visits.where(
      "user_agent ~* ? OR country IN (?)",
      BOT_PATTERNS.map(&:source).join('|'),
      BOT_COUNTRIES
    )

    # Statistics
    @total_bot_visits = all_bot_visits.count
    @bot_agent_count = bot_user_agent_visits.count
    @bot_country_count = bot_country_visits.count
    @total_visits = base_visits.count
    @bot_percentage = @total_visits > 0 ? ((@total_bot_visits.to_f / @total_visits) * 100).round(1) : 0

    # Top bot countries
    @bot_countries = bot_country_visits
                       .group(:country, :city)
                       .order('count_all DESC')
                       .limit(15)
                       .count
                       .map { |k, v| { country: k[0], city: k[1], visits: v } }

    # Top bot user agents
    @bot_agents = bot_user_agent_visits
                    .group(:user_agent)
                    .order('count_all DESC')
                    .limit(10)
                    .count
                    .map { |agent, count| { agent: agent, visits: count } }

    # Bot referrers
    @bot_referrers = all_bot_visits
                       .group(:referring_domain)
                       .order('count_all DESC')
                       .limit(10)
                       .count
                       .map { |domain, count| { domain: domain || 'Direct', visits: count } }

    # Daily bot traffic trend
    @bot_daily = all_bot_visits
                   .group(Arel.sql("DATE(started_at)"))
                   .order(Arel.sql("DATE(started_at)"))
                   .count
                   .map { |date, count| { date: date.to_s, count: count } }

    render partial: 'admin/analytics/bot_traffic'
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
