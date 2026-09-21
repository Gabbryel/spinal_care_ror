class AdminController < ApplicationController
  include AnalyticsFilterHelper
  
  layout "dashboard"

  # The analytics page checks `access` in its view, but the lazy-loaded
  # sections are separate requests that rendered their data to any signed-in
  # user. Keep the whole analytics surface admin-only.
  before_action :require_admin_for_analytics, if: -> { action_name.start_with?("analytics") }

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
    @channel = AnalyticsFilterHelper::CHANNEL_FILTERS.key?(params[:channel].to_s) ? params[:channel] : nil
    
    # Calculate date range based on period
    dates = calculate_period_dates
    @start_date = dates[:start_date]
    @end_date = dates[:end_date]
    
    # KPIs are cached per period/filter set (see AnalyticsFilterHelper).
    kpis = cached_analytics(:kpis) do
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
    
      # Page views only ($view, not $click), and only from the same filtered
      # visits as the visitor KPIs, so the "Top pagină" card agrees with them.
      events = Ahoy::Event.where(name: "$view")
                          .where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                          .where('time >= ? AND time <= ?', @start_date, @end_date)
                          .where(visit_id: public_visits.select(:id))
    
      top_page_raw = events.group(Arel.sql("properties->>'url'"))
                           .order('count_all DESC')
                           .limit(1)
                           .count
                           .first
      @top_page = top_page_raw ? [normalize_url(top_page_raw[0]), top_page_raw[1]] : ['/', 0]
    
      # Trend: same URL (raw, not normalized), same filters, previous period
      prev_events = Ahoy::Event.where(name: "$view")
                                .where("properties->>'url' NOT LIKE ? OR properties->>'url' IS NULL", '%/dashboard%')
                                .where('time >= ? AND time < ?', prev_start, @start_date)
                                .where(visit_id: prev_visits.select(:id))
      prev_page_count = top_page_raw ? prev_events.where("properties->>'url' = ?", top_page_raw[0]).count : 0
      @page_change_pct = prev_page_count > 0 ? (((@top_page[1] - prev_page_count).to_f / prev_page_count) * 100).round(1) : 0
      { total_visitors: @total_visitors, unique_visitors: @unique_visitors, daily_average: @daily_average, visitors_change_pct: @visitors_change_pct, unique_change_pct: @unique_change_pct, daily_change_pct: @daily_change_pct, top_location: @top_location, location_change_pct: @location_change_pct, top_source: @top_source, source_change_pct: @source_change_pct, top_page: @top_page, page_change_pct: @page_change_pct }
    end
    kpis.each { |name, value| instance_variable_set("@#{name}", value) }
  end
  
  # PHASE 2: Lazy-loaded sections
  def analytics_daily_chart
    render_cached_analytics_section(:daily_chart, 'admin/analytics/daily_chart') do
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
    
    end
  end
  
  def analytics_geography
    render_cached_analytics_section(:geography, 'admin/analytics/geography') do
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
    
      @top_countries = public_visits.where.not(country: [nil, ''])
                                          .group(:country)
                                          .order('count_all DESC')
                                          .limit(10)
                                          .count
    
    end
  end
  
  def analytics_sources
    render_cached_analytics_section(:sources, 'admin/analytics/sources') do
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
    
    end
  end
  
  def analytics_pages
    render_cached_analytics_section(:pages, 'admin/analytics/pages') do
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
    
    end
  end
  
  def edit_users
    @users = User.all.order(email: :asc)
  end

  # Labels for the `category` property of "$click" events (set by
  # click_tracker_controller.js, backfilled by CleanUpClickEvents).
  CLICK_CATEGORY_LABELS = {
    'call' => 'Apel telefonic',
    'booking' => 'Programare',
    'email' => 'Email',
    'whatsapp' => 'WhatsApp',
    'social' => 'Social media',
    'map' => 'Hartă',
    'nav' => 'Navigare în site',
    'external' => 'Link extern'
  }.freeze

  CONVERSION_TILES = [
    { label: 'Apeluri telefonice', categories: %w[call], css: 'kpi-success',
      tooltip: 'Apăsări pe numărul de telefon (link tel:) din meniu, subsol și pagini' },
    { label: 'Programări (buton)', categories: %w[booking], css: 'kpi-primary',
      tooltip: 'Apăsări pe butonul „Programare” / „Programează-te”, care deschide site-ul de programări' },
    { label: 'Email + WhatsApp', categories: %w[email whatsapp], css: 'kpi-info',
      tooltip: 'Apăsări pe adrese de email și link-uri WhatsApp' },
    { label: 'Social + Hartă', categories: %w[social map], css: 'kpi-warning',
      tooltip: 'Apăsări pe Facebook, Instagram și link-uri către hartă' }
  ].freeze

  DAILY_CHART_CATEGORIES = %w[call booking].freeze

  # Clicks & conversions section. `page` narrows the per-page table; it is
  # part of the cache key so each selection is cached separately.
  def analytics_clicks
    @selected_page = params[:page].presence
    render_cached_analytics_section([:clicks, @selected_page], 'admin/analytics/clicks') do
      dates = calculate_period_dates
      start_date = dates[:start_date]
      end_date = dates[:end_date]
      filter_bots = params[:filter_bots] != 'false'
      filter_geography = params[:filter_geography] == 'true'

      base_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                               .where('started_at >= ? AND started_at <= ?', start_date, end_date)
      public_visits = apply_analytics_filters(base_visits, include_bots: !filter_bots, relevant_countries_only: filter_geography)

      prev_start = start_date - (end_date - start_date)
      prev_base = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                             .where('started_at >= ? AND started_at < ?', prev_start, start_date)
      prev_visits = apply_analytics_filters(prev_base, include_bots: !filter_bots, relevant_countries_only: filter_geography)

      clicks = Ahoy::Event.where(name: '$click')
                          .where('time >= ? AND time <= ?', start_date, end_date)
                          .where(visit_id: public_visits.select(:id))
      prev_clicks = Ahoy::Event.where(name: '$click')
                               .where('time >= ? AND time < ?', prev_start, start_date)
                               .where(visit_id: prev_visits.select(:id))

      @unique_visitors = public_visits.distinct.count(:visitor_token)
      by_category = clicks.group(Arel.sql("properties->>'category'")).count
      prev_by_category = prev_clicks.group(Arel.sql("properties->>'category'")).count
      @total_clicks = by_category.values.sum

      @conversion_tiles = CONVERSION_TILES.map do |tile|
        count = tile[:categories].sum { |c| by_category[c] || 0 }
        prev = tile[:categories].sum { |c| prev_by_category[c] || 0 }
        tile.merge(
          count: count,
          change_pct: prev > 0 ? (((count - prev).to_f / prev) * 100).round(1) : 0,
          per_100_visitors: @unique_visitors > 0 ? (count * 100.0 / @unique_visitors).round(1) : 0
        )
      end

      days_count = (end_date.to_date - start_date.to_date).to_i + 1
      daily = clicks.where("properties->>'category' IN (?)", DAILY_CHART_CATEGORIES)
                    .group(Arel.sql("properties->>'category'"), Arel.sql("DATE(time)"))
                    .count
      days = (0...days_count).map { |i| start_date.to_date + i.days }
      @daily_labels = days.map { |d| d.strftime('%d %b') }
      @daily_series = DAILY_CHART_CATEGORIES.map do |category|
        { label: CLICK_CATEGORY_LABELS[category], data: days.map { |d| daily[[category, d]] || 0 } }
      end

      @top_destinations = clicks.group(Arel.sql("properties->>'category'"), Arel.sql("properties->>'destination'"))
                                .order('count_all DESC')
                                .limit(15)
                                .count
                                .map { |(category, destination), count| { category: category, destination: pretty_destination(destination), count: count } }

      @top_pages = clicks.group(Arel.sql("properties->>'page'"))
                         .order('count_all DESC')
                         .limit(20)
                         .count
                         .map { |path, count| { path: path, label: normalize_url(path), count: count } }
      @selected_page ||= @top_pages.first&.dig(:path)
      page_clicks = @selected_page ? clicks.where("properties->>'page' = ?", @selected_page) : clicks.none
      # Clicks recorded before the tracker collapsed whitespace carry the
      # element's raw text (newlines, indentation); group on the squished form.
      @page_clicks = page_clicks.group(Arel.sql("properties->>'category'"), Arel.sql("properties->>'destination'"),
                                       Arel.sql("regexp_replace(trim(properties->>'text'), '\\s+', ' ', 'g')"))
                                .order('count_all DESC')
                                .limit(20)
                                .count
                                .map { |(category, destination, text), count| { category: category, destination: pretty_destination(destination), text: text.to_s.truncate(60), count: count } }
      @page_total = page_clicks.count
      @selected_page_label = @selected_page ? normalize_url(@selected_page) : nil
    end
  end

  # Audit (can the data be trusted?) and interpretation (what does it say?)
  # of the period, produced by AnalyticsInsights.
  def analytics_audit
    render_cached_analytics_section(:audit, 'admin/analytics/audit') do
      dates = calculate_period_dates
      start_date = dates[:start_date]
      end_date = dates[:end_date]
      filter_bots = params[:filter_bots] != 'false'
      filter_geography = params[:filter_geography] == 'true'

      base_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                               .where('started_at >= ? AND started_at <= ?', start_date, end_date)
      public_visits = apply_analytics_filters(base_visits, include_bots: !filter_bots, relevant_countries_only: filter_geography)
      prev_start = start_date - (end_date - start_date)
      prev_base = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                             .where('started_at >= ? AND started_at < ?', prev_start, start_date)
      prev_visits = apply_analytics_filters(prev_base, include_bots: !filter_bots, relevant_countries_only: filter_geography)

      insights = AnalyticsInsights.new(visits: public_visits, prev_visits: prev_visits, all_visits: base_visits,
                                       start_date: start_date, end_date: end_date)
      @audit = insights.audit
      @insights = insights.insights
      @audit_summary = @audit.group_by(&:level).transform_values(&:size)
    end
  end

  # Visitor behaviour: paths to contact, decision time, returning visitors,
  # doctor pages, dead ends, devices, timing, campaigns, engagement, booking
  # funnel, call tallies, search terms, price list, 404s (BehaviourAnalytics).
  def analytics_behaviour
    render_cached_analytics_section(:behaviour, 'admin/analytics/behaviour') do
      dates = calculate_period_dates
      start_date = dates[:start_date]
      end_date = dates[:end_date]
      filter_bots = params[:filter_bots] != 'false'
      filter_geography = params[:filter_geography] == 'true'
      base_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                               .where('started_at >= ? AND started_at <= ?', start_date, end_date)
      public_visits = apply_analytics_filters(base_visits, include_bots: !filter_bots, relevant_countries_only: filter_geography)
      b = BehaviourAnalytics.new(visits: public_visits, start_date: start_date, end_date: end_date)
      @total_visits = b.total_visits
      @paths = b.paths_to_contact
      @decision = b.decision_time
      @landing = b.landing_intent
      @returning = b.returning
      @doctors = b.doctor_funnel
      @dead_ends = b.dead_ends
      @devices = b.devices
      @heat = b.heat
      @campaigns = b.campaigns
      @engagement = b.engagement
      @booking = b.booking_funnel
      @tally = b.call_tally
      @searches = b.search_terms
      @price_list = b.price_list
      @not_found = b.not_found
      @weekdays = BehaviourAnalytics::WEEKDAYS
    end
  end

  # Reception types in how many calls came in on a day (see BehaviourAnalytics#call_tally).
  def analytics_call_tally
    tally = CallTally.find_or_initialize_by(date: params[:date])
    tally.calls = params[:calls].to_i
    tally.note = params[:note].presence
    if tally.save
      Rails.cache.delete_matched('analytics/behaviour*') rescue nil
      flash[:notice] = "Apeluri notate pentru #{tally.date.strftime('%d.%m.%Y')}: #{tally.calls}."
    else
      flash[:alert] = "Nu am putut salva: #{tally.errors.full_messages.join(', ')}"
    end
    redirect_to dashboard_analytics_path(period: params[:period].presence || '30')
  end

  # Paid vs organic: every channel side by side, Google Ads campaigns, spend.
  # Ignores the page's channel filter (it compares the channels).
  def analytics_channels
    render_cached_analytics_section(:channels, 'admin/analytics/channels') do
      dates = calculate_period_dates
      start_date = dates[:start_date]
      end_date = dates[:end_date]
      filter_bots = params[:filter_bots] != 'false'
      filter_geography = params[:filter_geography] == 'true'
      base_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
                               .where('started_at >= ? AND started_at <= ?', start_date, end_date)
      visits = apply_analytics_filters(base_visits, include_bots: !filter_bots, relevant_countries_only: filter_geography, channel: 'all')
      c = ChannelAnalytics.new(visits: visits, start_date: start_date, end_date: end_date)
      @channels = c.channels
      @groups = c.groups
      @campaigns = c.campaigns
      @spend = c.spend
      @monthly = c.monthly
      @labels = AnalyticsFilterHelper::CHANNEL_LABELS
    end
  end

  # Admin names a Google Ads campaign id (the URL carries only the id).
  def analytics_campaign_name
    record = AdCampaignName.find_or_initialize_by(campaign_id: params[:campaign_id].to_s.strip)
    record.name = params[:name].to_s.strip
    if record.name.present? && record.save
      Rails.cache.delete_matched('analytics/channels*') rescue nil
      flash[:notice] = "Campania #{record.campaign_id} se numește acum „#{record.name}”."
    else
      flash[:alert] = 'Numele campaniei nu a putut fi salvat.'
    end
    redirect_to dashboard_analytics_path(period: params[:period].presence || '30')
  end

  # Admin types the month's ad spend (lei), per channel.
  def analytics_ad_spend
    month = Date.parse("#{params[:month]}-01") rescue nil
    spend = month && AdSpend.find_or_initialize_by(month: month, channel: params[:channel_key].presence || 'paid_google')
    if spend
      spend.amount = params[:amount].to_s.tr(',', '.').to_d
      spend.note = params[:note].presence
    end
    if spend&.save
      Rails.cache.delete_matched('analytics/channels*') rescue nil
      flash[:notice] = "Cheltuială notată pentru #{I18n.l(month, format: '%m.%Y')}: #{spend.amount.to_i} lei."
    else
      flash[:alert] = 'Cheltuiala nu a putut fi salvată (luna în format AAAA-LL, suma în lei).'
    end
    redirect_to dashboard_analytics_path(period: params[:period].presence || '30')
  end

  def analytics_hourly
    render_cached_analytics_section(:hourly, 'admin/analytics/hourly') do
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
    
    end
  end

  def analytics_geo_sources
    render_cached_analytics_section(:geo_sources, 'admin/analytics/geo_sources') do
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
    
    end
  end

  def analytics_bot_traffic
    render_cached_analytics_section(:bot_traffic, 'admin/analytics/bot_traffic') do
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
    end
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
  
  def job_postings
    @job_posting = JobPosting.new
    @job_postings = JobPosting.all.order(created_at: :desc)
  end
  
  def promo_packages
    @promo_package = PromoPackage.new
    @promo_packages = PromoPackage.all.order(created_at: :desc)
  end
  
  def medicines_consumption
    @medicines_consumption = MedicinesConsumption.new
    @consumptions = MedicinesConsumption.all.order(year: :desc, month: :desc)
    @years = @consumptions.pluck(:year).uniq.sort.reverse
  end
  
  # Activity journal: one card per user, and the selected user's report
  # (summary + day-by-day sentences) built by AuditUserReport.
  PERIODS = { '7' => '7 zile', '30' => '30 zile', '90' => '90 zile', 'all' => 'Tot' }.freeze

  def audit
    # Non-admins get the view's no-access block; skip the queries (Bullet
    # flags eager loads that are never rendered).
    @user_cards = []
    return unless current_user&.admin

    @period = PERIODS.key?(params[:period].to_s) ? params[:period].to_s : '30'
    logs = AuditLog.all
    logs = logs.where('created_at >= ?', @period.to_i.days.ago.beginning_of_day) unless @period == 'all'

    counts = logs.group(:user_id, :action).count
    last_seen = logs.group(:user_id).maximum(:created_at)
    users = User.where(id: counts.keys.map(&:first).uniq).index_by(&:id)
    @user_cards = last_seen.sort_by { |_, at| -at.to_i }.map do |user_id, at|
      user = users[user_id] or next
      by_action = counts.select { |(uid, _), _| uid == user_id }.transform_keys(&:last)
      changes = by_action.sum { |action, n| action.in?(%w[view login logout]) ? 0 : n }
      { user: user, last_at: at, changes: changes, logins: by_action['login'] || 0, views: by_action['view'] || 0 }
    end.compact

    # Global search ("who changed X?"): every user, all time, replaces the
    # per-user report while a query is present.
    @q = params[:q].to_s.squish
    @search = AuditSearch.new(@q) if @q.present?

    @selected_user = params[:user].present? ? User.find_by(id: params[:user]) : @user_cards.first&.dig(:user)
    return unless @selected_user && @search.nil?

    user_logs = logs.where(user_id: @selected_user.id).includes(:user).order(created_at: :desc).to_a
    AuditSearch.preload_auditables(user_logs)
    @report = AuditUserReport.new(@selected_user, user_logs)
  end

  def test
    @profession = Profession.new()
    @professions = Profession.all.order(name: :asc)
    @specialty = Specialty.new()
    @specialties = Specialty.all.order(name: :asc)
  end
  
  private
  
  def require_admin_for_analytics
    head :forbidden unless current_user&.admin
  end

  def normalize_url(url)
    path = url.to_s.gsub(/^https?:\/\/[^\/]+/, '')
    return 'Homepage' if path.blank? || path == '/'
    path
  end

  # Short label for a "$click" destination: site links become paths, tel:/mailto:
  # lose their scheme, everything else keeps host + path.
  def pretty_destination(destination)
    d = destination.to_s
    return d.sub(/\A(tel|mailto):/i, '') if d.match?(/\A(tel|mailto):/i)
    return normalize_url(d) if d.match?(%r{\Ahttps?://(www\.)?spinalcare\.ro(/|\z)}i)
    d.sub(%r{\Ahttps?://(www\.)?}i, '').sub(/\?.*\z/, '').truncate(70)
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
