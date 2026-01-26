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
    # ===== PERIOD FILTER SETUP =====
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
    
    # Calculate comparison period (same duration, immediately before current period)
    period_duration = @end_date - @start_date
    @previous_period_start = @start_date - period_duration
    @previous_period_end = @start_date - 1.second
    
    # ===== BASE QUERIES =====
    # Public visits for current period (exclude /dashboard URLs)
    public_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                                .where('started_at >= ? AND started_at <= ?', @start_date, @end_date)
    
    # Public visits for comparison period
    previous_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                                  .where('started_at >= ? AND started_at <= ?', @previous_period_start, @previous_period_end)
    
    # Events for current period
    events = Ahoy::Event.where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                        .where('time >= ? AND time <= ?', @start_date, @end_date)
    
    # Events for comparison period
    previous_events = Ahoy::Event.where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                                  .where('time >= ? AND time <= ?', @previous_period_start, @previous_period_end)
    
    # ===== HERO KPI DASHBOARD =====
    # Total Visits
    @total_visits = public_visits.count
    @previous_total_visits = previous_visits.count
    @total_visits_change = @total_visits - @previous_total_visits
    @total_visits_change_pct = calculate_percentage_change(@total_visits, @previous_total_visits)
    
    # Unique Visitors
    @unique_visitors = public_visits.distinct.count(:visitor_token)
    @previous_unique_visitors = previous_visits.distinct.count(:visitor_token)
    @unique_visitors_change = @unique_visitors - @previous_unique_visitors
    @unique_visitors_change_pct = calculate_percentage_change(@unique_visitors, @previous_unique_visitors)
    
    # Pages per Visit
    total_events = events.count
    @pages_per_visit = @total_visits > 0 ? (total_events.to_f / @total_visits).round(2) : 0
    previous_total_events = previous_events.count
    previous_total_visits_count = @previous_total_visits
    @previous_pages_per_visit = previous_total_visits_count > 0 ? (previous_total_events.to_f / previous_total_visits_count).round(2) : 0
    @pages_per_visit_change_pct = calculate_percentage_change(@pages_per_visit, @previous_pages_per_visit)
    
    # Bounce Rate (single page visits / total visits)
    single_page_visits = events.group(:visit_id).having('COUNT(*) = 1').count.length
    @bounce_rate = @total_visits > 0 ? ((single_page_visits.to_f / @total_visits) * 100).round(1) : 0
    previous_single_page_visits = previous_events.group(:visit_id).having('COUNT(*) = 1').count.length
    @previous_bounce_rate = previous_total_visits_count > 0 ? ((previous_single_page_visits.to_f / previous_total_visits_count) * 100).round(1) : 0
    @bounce_rate_change_pct = calculate_percentage_change(@bounce_rate, @previous_bounce_rate)
    
    # Avg Session Duration (estimate: avg pages * 2.5 min avg time per page)
    @avg_session_duration = (@pages_per_visit * 2.5).round(1)
    @previous_avg_session_duration = (@previous_pages_per_visit * 2.5).round(1)
    @avg_session_duration_change_pct = calculate_percentage_change(@avg_session_duration, @previous_avg_session_duration)
    
    # Real-time Visitors (last 5 minutes)
    @realtime_visitors = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                                    .where('started_at >= ?', 5.minutes.ago)
                                    .distinct
                                    .count(:visitor_token)
    
    # New vs Returning Visitors
    visitor_counts = public_visits.group(:visitor_token).count
    @new_visitors = visitor_counts.count { |_, count| count == 1 }
    @returning_visitors = @unique_visitors - @new_visitors
    previous_visitor_counts = previous_visits.group(:visitor_token).count
    @previous_new_visitors = previous_visitor_counts.count { |_, count| count == 1 }
    @previous_returning_visitors = @previous_unique_visitors - @previous_new_visitors
    
    # ===== TIME-BASED PERFORMANCE =====
    # Hourly Distribution (24 hours)
    hourly_data = public_visits.group("EXTRACT(HOUR FROM started_at)").count
    @hourly_visits = (0..23).map { |hour| { hour: "#{hour}:00", count: hourly_data[hour.to_f] || 0 } }
    
    # Daily visits (limit to period, max 90 days for performance)
    days_count = [((@end_date.to_date - @start_date.to_date).to_i), 90].min
    daily_data = public_visits.group("DATE(started_at)").count
    @daily_visits = (0..days_count).map do |i|
      date = i.days.ago(@end_date).to_date
      { date: date.strftime('%d %b'), count: daily_data[date] || 0 }
    end.reverse
    
    # Day of Week Performance
    dow_data = public_visits.group("EXTRACT(DOW FROM started_at)").count
    dow_names = ['Duminică', 'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă']
    @visits_by_day_of_week = (0..6).map do |dow|
      { day: dow_names[dow], count: dow_data[dow.to_f] || 0 }
    end
    
    # Hour of Day Heatmap (last 7 days × 24 hours)
    heatmap_start = 7.days.ago(@end_date)
    heatmap_visits = public_visits.where('started_at >= ?', heatmap_start)
                                  .group("DATE(started_at)", "EXTRACT(HOUR FROM started_at)")
                                  .count
    @heatmap_data = (0..6).map do |day_offset|
      date = day_offset.days.ago(@end_date).to_date
      {
        date: date.strftime('%a %d'),
        hours: (0..23).map { |hour| heatmap_visits[[date, hour.to_f]] || 0 }
      }
    end.reverse
    
    # Today's Performance
    today_start = Time.zone.now.beginning_of_day
    @visits_today = public_visits.where('started_at >= ?', today_start).count
    @unique_visitors_today = public_visits.where('started_at >= ?', today_start).distinct.count(:visitor_token)
    
    # This Week Performance
    week_start = 1.week.ago(@end_date)
    @visits_this_week = public_visits.where('started_at >= ?', week_start).count
    @unique_visitors_this_week = public_visits.where('started_at >= ?', week_start).distinct.count(:visitor_token)
    
    # This Month Performance
    month_start = 1.month.ago(@end_date)
    @visits_this_month = public_visits.where('started_at >= ?', month_start).count
    @unique_visitors_this_month = public_visits.where('started_at >= ?', month_start).distinct.count(:visitor_token)
    
    # Weekly Growth (if period allows)
    @weekly_growth = 0
    if (@end_date - @start_date) >= 2.weeks
      one_week_ago = 1.week.ago(@end_date)
      visits_this_week_calc = public_visits.where('started_at >= ?', one_week_ago).count
      visits_last_week = public_visits.where('started_at < ?', one_week_ago).count
      @weekly_growth = calculate_percentage_change(visits_this_week_calc, visits_last_week)
    end
    
    # ===== TRAFFIC SOURCE ANALYSIS =====
    # Basic Traffic Sources (added LinkedIn)
    traffic_data = public_visits.group(:referrer, :referring_domain).count
    @traffic_by_source = {
      'Direct' => traffic_data.select { |k, _| k[0].nil? }.values.sum,
      'Google' => traffic_data.select { |k, _| k[1]&.include?('google') }.values.sum,
      'Facebook' => traffic_data.select { |k, _| k[1]&.include?('facebook') }.values.sum,
      'Instagram' => traffic_data.select { |k, _| k[1]&.include?('instagram') }.values.sum,
      'LinkedIn' => traffic_data.select { |k, _| k[1]&.include?('linkedin') }.values.sum
    }
    @traffic_by_source['Alte surse'] = @total_visits - @traffic_by_source.values.sum
    
    # UTM Campaign Tracking
    @utm_sources = public_visits.where.not(utm_source: nil)
                                .group(:utm_source)
                                .order('count_all DESC')
                                .limit(10)
                                .count
    
    @utm_mediums = public_visits.where.not(utm_medium: nil)
                                .group(:utm_medium)
                                .order('count_all DESC')
                                .limit(10)
                                .count
    
    @utm_campaigns = public_visits.where.not(utm_campaign: nil)
                                  .group(:utm_campaign)
                                  .order('count_all DESC')
                                  .limit(10)
                                  .count
    
    # Top Referrers with Percentage (LIMIT 20)
    referrer_data = public_visits.where.not(referrer: nil)
                                 .group(:referring_domain)
                                 .order('count_all DESC')
                                 .limit(20)
                                 .count
    @total_referrer_visits = referrer_data.values.sum
    @top_referrers_with_percentage = referrer_data.transform_values do |count|
      { count: count, percentage: @total_referrer_visits > 0 ? ((count.to_f / @total_referrer_visits) * 100).round(2) : 0 }
    end
    
    # Browser, OS, Device Distribution
    @browsers = public_visits.group(:browser).order('count_all DESC').limit(8).count
    @operating_systems = public_visits.group(:os).order('count_all DESC').limit(8).count
    @device_types = public_visits.group(:device_type).order('count_all DESC').count
    
    # ===== MEDICAL SERVICES ANALYTICS =====
    # Service page views (from events)
    service_events = events.where("properties->>'url' LIKE ?", '%/servicii-medicale/%')
    @service_page_views = service_events.count
    @service_unique_visitors = service_events.distinct.count(:visit_id)
    
    # Top Viewed Service Pages (LIMIT 15)
    @top_service_pages = service_events.group(Arel.sql("properties->>'url'"))
                                       .order('count_all DESC')
                                       .limit(15)
                                       .count
                                       .transform_keys { |url| normalize_url(url) }
    
    # Services with Attached Members vs Standalone
    @services_with_members = MedicalService.where.not(member_id: nil).count
    @services_without_members = MedicalService.where(member_id: nil).count
    
    # ===== DOCTOR PROFILE ANALYTICS =====
    # Member profile page views
    member_events = events.where("properties->>'url' LIKE ?", '%/echipa/%')
    @member_page_views = member_events.count
    @member_unique_visitors = member_events.distinct.count(:visit_id)
    
    # Top Viewed Member Profiles (LIMIT 15)
    @top_member_pages = member_events.group(Arel.sql("properties->>'url'"))
                                     .order('count_all DESC')
                                     .limit(15)
                                     .count
                                     .transform_keys { |url| normalize_url(url) }
    
    # Members with Bio vs Without
    @members_with_bio = Member.joins(:rich_text_description)
                              .where.not(action_text_rich_texts: { body: [nil, ''] })
                              .count rescue 0
    @members_without_bio = Member.count - @members_with_bio
    
    # Members with Photo vs Without
    @members_with_photo = Member.joins(:photo_attachment).distinct.count rescue 0
    @members_without_photo = Member.count - @members_with_photo
    
    # ===== GEOGRAPHIC INTELLIGENCE =====
    # Countries (LIMIT 15)
    @visitors_by_country = public_visits.where.not(country: [nil, ''])
                                        .group(:country)
                                        .order('count_all DESC')
                                        .limit(15)
                                        .count
    
    # Romania - Counties (LIMIT 20)
    @visitors_by_county = public_visits.where(country: ['Romania', 'RO'])
                                       .where.not(region: [nil, ''])
                                       .group(:region)
                                       .order('count_all DESC')
                                       .limit(20)
                                       .count
    
    # Romania - Cities (LIMIT 20)
    @visitors_by_city_romania = public_visits.where(country: ['Romania', 'RO'])
                                             .where.not(city: [nil, ''])
                                             .group(:city)
                                             .order('count_all DESC')
                                             .limit(20)
                                             .count
    
    # ===== PAGE PERFORMANCE =====
    # Most Viewed Pages (LIMIT 20)
    @most_viewed_pages = events.group(Arel.sql("properties->>'url'"))
                               .order('count_all DESC')
                               .limit(20)
                               .count
                               .transform_keys { |url| normalize_url(url) }
    
    # Entry Pages (LIMIT 15)
    @top_entry_pages = public_visits.where.not(landing_page: [nil, ''])
                                    .group(:landing_page)
                                    .order('count_all DESC')
                                    .limit(15)
                                    .count
                                    .transform_keys { |url| normalize_url(url) }
    
    # Exit Pages (LIMIT 15)
    @top_exit_pages = events.group(Arel.sql("properties->>'url'"))
                            .order('count_all DESC')
                            .limit(15)
                            .count
                            .transform_keys { |url| normalize_url(url) }
    
    # ===== ENGAGEMENT & INTERACTION =====
    # Click Analytics
    click_events = events.where(name: ['click', '$click'])
    @total_clicks = click_events.count
    
    @top_click_destinations = click_events.group(Arel.sql("properties->>'destination'"))
                                          .order('count_all DESC')
                                          .limit(10)
                                          .count
                                          .transform_keys { |dest| dest&.gsub(/^https?:\/\/[^\/]+/, '')&.presence || dest }
    
    @top_clicked_elements = click_events.group(Arel.sql("properties->>'text'"))
                                        .order('count_all DESC')
                                        .limit(10)
                                        .count
    
    @clicks_by_page = click_events.group(Arel.sql("properties->>'page'"))
                                  .order('count_all DESC')
                                  .limit(10)
                                  .count
                                  .transform_keys { |page| page&.presence || '/' }
    
    @clicks_by_type = click_events.group(Arel.sql("properties->>'element_type'")).count
    
    # ===== CONTENT STATISTICS =====
    # Basic counts
    @total_members = Member.count
    @total_services = MedicalService.count
    @total_specialties = Specialty.count
    @total_professions = Profession.count
    @total_facts = Fact.count
    @total_users = User.count
    
    # User role counts
    user_counts = User.group(:admin, :god_mode).count
    @admin_users = user_counts.select { |k, _| k[0] == true }.values.sum
    @god_mode_users = user_counts.select { |k, _| k[1] == true }.values.sum
    
    # Services per Specialty
    @services_per_specialty = MedicalService.group(:specialty_id).count
    @members_per_profession = Member.group(:profession_id).count
    @members_per_specialty = Member.where.not(specialty_id: nil).group(:specialty_id).count
    
    # Services without description
    @services_without_description = @total_services - (MedicalService.joins(:rich_text_description)
                                                                      .where.not(action_text_rich_texts: { body: [nil, ''] })
                                                                      .count rescue 0)
    
    # Coverage metrics
    @specialties_with_members = @members_per_specialty.keys.uniq.size
    @specialties_without_members = @total_specialties - @specialties_with_members
    
    @professions_with_members = @members_per_profession.keys.uniq.size
    @professions_without_members = @total_professions - @professions_with_members
    
    @specialties_with_services = @services_per_specialty.keys.uniq.size
    @specialties_without_services = @total_specialties - @specialties_with_services
    
    # Members without specialty
    @members_without_specialty = Member.where(specialty_id: nil).count
    
    # ===== RECENT ACTIVITY =====
    # Time-based content creation
    @members_created_this_month = Member.where('created_at >= ? AND created_at <= ?', @start_date, @end_date).count
    @services_created_this_month = MedicalService.where('created_at >= ? AND created_at <= ?', @start_date, @end_date).count
    @facts_updated_this_week = Fact.where('updated_at >= ? AND updated_at <= ?', @start_date, @end_date).count
    @users_created_this_month = User.where('created_at >= ? AND created_at <= ?', @start_date, @end_date).count
    
    # Recent updates (LIMIT 5 each)
    @recent_members = Member.select(:id, :first_name, :last_name, :updated_at).order(updated_at: :desc).limit(5)
    @recent_services = MedicalService.select(:id, :name, :updated_at).order(updated_at: :desc).limit(5)
    @recent_facts = Fact.select(:id, :title, :updated_at).order(updated_at: :desc).limit(5)
    @recent_users = User.select(:id, :email, :updated_at).order(updated_at: :desc).limit(5)
    
    # Most updated (LIMIT 10)
    @most_updated_members = Member.select(:id, :first_name, :last_name, :updated_at).order(updated_at: :desc).limit(10)
    @most_updated_services = MedicalService.select(:id, :name, :updated_at).order(updated_at: :desc).limit(10)
    
    # ===== GROWTH TRENDS =====
    # 6-month content growth
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
    
    # Top Specialties and Professions (LIMIT 10)
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
    
    # Database metrics
    @total_records = @total_members + @total_services + @total_specialties + @total_professions + @total_facts + @total_users
    
    # ===== PATIENT JOURNEY ANALYTICS =====
    # Common Visit Paths (top 15 multi-page journeys)
    multi_page_visits = events.group(:visit_id)
                              .having('COUNT(*) > 1')
                              .order(Arel.sql('COUNT(*) DESC'))
                              .limit(15)
                              .pluck(:visit_id)
    
    @common_paths = multi_page_visits.map do |visit_id|
      path = events.where(visit_id: visit_id)
                   .order(:time)
                   .pluck(Arel.sql("properties->>'url'"))
                   .map { |url| normalize_url(url) }
      { path: path, steps: path.size }
    end.group_by { |p| p[:path] }
       .transform_values { |v| v.size }
       .sort_by { |_, count| -count }
       .first(10)
       .to_h
    
    # Average path length
    @avg_path_length = (@pages_per_visit * @total_visits).to_i / [@total_visits, 1].max
    
    # Drop-off Analysis: Pages with highest exit rates
    exit_page_counts = events.group(:visit_id)
                             .select('visit_id, MAX(time) as last_time')
                             .map do |visit|
      events.where(visit_id: visit.visit_id, time: visit.last_time)
            .pluck(Arel.sql("properties->>'url'"))
            .first
    end.compact
    
    exit_distribution = exit_page_counts.group_by(&:itself)
                                        .transform_values(&:size)
                                        .sort_by { |_, count| -count }
                                        .first(15)
    
    @high_exit_pages = exit_distribution.map do |url, count|
      normalized_url = normalize_url(url)
      page_views = events.where("properties->>'url' = ?", url).count
      exit_rate = page_views > 0 ? ((count.to_f / page_views) * 100).round(1) : 0
      { page: normalized_url, exits: count, views: page_views, exit_rate: exit_rate }
    end
    
    # Returning Visitor Patterns
    returning_visitor_data = public_visits.group(:visitor_token)
                                          .having('COUNT(*) > 1')
                                          .order('COUNT(*) DESC')
                                          .limit(100)
                                          .pluck(:visitor_token, 'COUNT(*) as visit_count')
    
    @returning_visitor_distribution = {
      '2 visits' => returning_visitor_data.count { |_, count| count == 2 },
      '3-5 visits' => returning_visitor_data.count { |_, count| count >= 3 && count <= 5 },
      '6-10 visits' => returning_visitor_data.count { |_, count| count >= 6 && count <= 10 },
      '11+ visits' => returning_visitor_data.count { |_, count| count > 10 }
    }
    
    # Average time between visits for returning visitors
    returning_visit_gaps = returning_visitor_data.first(20).map do |token, _|
      visits = public_visits.where(visitor_token: token)
                            .order(:started_at)
                            .pluck(:started_at)
      next nil if visits.size < 2
      
      gaps = visits.each_cons(2).map { |v1, v2| (v2 - v1) / 1.day }
      gaps.sum / gaps.size
    end.compact
    
    @avg_days_between_visits = returning_visit_gaps.any? ? (returning_visit_gaps.sum / returning_visit_gaps.size).round(1) : 0
    
    # Most revisited pages (by returning visitors)
    @most_revisited_pages = events.joins("INNER JOIN ahoy_visits ON ahoy_visits.id = ahoy_events.visit_id")
                                  .where("ahoy_visits.visitor_token IN (?)", returning_visitor_data.map(&:first))
                                  .group(Arel.sql("properties->>'url'"))
                                  .order('count_all DESC')
                                  .limit(10)
                                  .count
                                  .transform_keys { |url| normalize_url(url) }
    
    # Loyalty Segments
    @loyalty_segments = {
      new_visitors: @new_visitors,
      occasional: @returning_visitor_distribution['2 visits'] || 0,
      regular: (@returning_visitor_distribution['3-5 visits'] || 0) + (@returning_visitor_distribution['6-10 visits'] || 0),
      loyal: @returning_visitor_distribution['11+ visits'] || 0
    }

    # ===== MEDICINE CONSUMPTION ANALYTICS =====
    # Monthly Trends (last 12 months)
    @medicine_monthly = MedicinesConsumption.where('created_at >= ?', 12.months.ago)
                                            .group("DATE_TRUNC('month', created_at)")
                                            .select("DATE_TRUNC('month', created_at) as month, 
                                                    SUM(total_amount) as total_spent,
                                                    SUM(budget) as total_budget,
                                                    COUNT(*) as transaction_count")
                                            .order('month ASC')

    # Current Month Stats
    current_month_start = Date.today.beginning_of_month
    @current_month_spend = MedicinesConsumption.where('created_at >= ?', current_month_start).sum(:total_amount)
    @current_month_budget = MedicinesConsumption.where('created_at >= ?', current_month_start).sum(:budget)
    @current_month_variance = @current_month_budget > 0 ? 
                             (((@current_month_spend - @current_month_budget).to_f / @current_month_budget) * 100).round(1) : 0

    # Year-over-Year Comparison
    current_year_spend = MedicinesConsumption.where('EXTRACT(YEAR FROM created_at) = ?', Date.today.year)
                                             .sum(:total_amount)
    previous_year_spend = MedicinesConsumption.where('EXTRACT(YEAR FROM created_at) = ?', Date.today.year - 1)
                                              .sum(:total_amount)
    @medicine_yoy_change = calculate_percentage_change(current_year_spend, previous_year_spend)
    @current_year_spend = current_year_spend
    @previous_year_spend = previous_year_spend

    # Top Medications/Categories
    @top_medicines = MedicinesConsumption.where('created_at >= ?', 6.months.ago)
                                         .group(:medicine_name)
                                         .select('medicine_name, 
                                                 SUM(total_amount) as total_cost,
                                                 SUM(quantity) as total_quantity,
                                                 COUNT(*) as purchase_count')
                                         .order('total_cost DESC')
                                         .limit(10)

    # Average Monthly Spend (for forecasting)
    monthly_averages = MedicinesConsumption.where('created_at >= ?', 6.months.ago)
                                           .group("DATE_TRUNC('month', created_at)")
                                           .sum(:total_amount)
    @avg_monthly_spend = monthly_averages.values.any? ? 
                         (monthly_averages.values.sum / monthly_averages.values.size).round(2) : 0

    # Next Quarter Forecast (simple moving average)
    @next_quarter_forecast = (@avg_monthly_spend * 3).round(2)

    # Budget Compliance Rate (last 6 months)
    compliant_months = MedicinesConsumption.where('created_at >= ?', 6.months.ago)
                                           .group("DATE_TRUNC('month', created_at)")
                                           .select("DATE_TRUNC('month', created_at) as month,
                                                   SUM(total_amount) as spent,
                                                   SUM(budget) as budget")
                                           .to_a
                                           .count { |m| m.spent <= m.budget }
    total_months = compliant_months.count > 0 ? compliant_months.count : 6
    @budget_compliance_rate = total_months > 0 ? ((compliant_months.to_f / total_months) * 100).round(1) : 0
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
  
  def calculate_percentage_change(current, previous)
    return 0 if previous.nil? || previous.zero?
    (((current.to_f - previous.to_f) / previous.to_f) * 100).round(1)
  end

end
