module AnalyticsFilterHelper
  extend ActiveSupport::Concern

  # Bot user agent patterns (common crawlers, scrapers, spam bots)
  BOT_PATTERNS = [
    /bot/i, /crawl/i, /spider/i, /slurp/i, /scraper/i,
    /headless/i, /phantom/i, /puppeteer/i, /selenium/i,
    /curl/i, /wget/i, /python/i, /java/i, /perl/i,
    # Moz's crawler is "rogerbot"; a bare /moz/ would match "Mozilla/5.0", i.e. every real browser.
    /ahrefs/i, /semrush/i, /rogerbot/i, /majestic/i, /dotbot/i,
    /petalbot/i, /bingpreview/i, /yandex/i, /baidu/i,
    /dataforseo/i, /uptimerobot/i, /pingdom/i, /statuscode/i,
    /archive\.org/i, /wayback/i, /mediapartners/i,
    /feedfetcher/i, /rss/i, /scrapy/i, /webcopier/i
  ].freeze

  # Relevant countries for Romanian medical clinic
  RELEVANT_COUNTRIES = [
    'Romania', 'România', 'RO',
    'Moldova', 'Republica Moldova', 'MD',
    'Italy', 'Italia', 'IT',
    'Spain', 'España', 'Spania', 'ES',
    'United Kingdom', 'UK', 'GB', 'Marea Britanie',
    'Germany', 'Deutschland', 'Germania', 'DE',
    'France', 'Franța', 'FR',
    'Austria', 'AT',
    'Hungary', 'Magyarország', 'Ungaria', 'HU',
    'Bulgaria', 'България', 'BG',
    'Greece', 'Ελλάδα', 'Grecia', 'GR',
    'Serbia', 'Србија', 'RS',
    'Ukraine', 'Україна', 'Ucraina', 'UA'
  ].freeze

  # Bot-heavy countries (likely spam/scraper traffic)
  BOT_COUNTRIES = [
    'Vietnam', 'Viet Nam', 'VN',
    'Brazil', 'Brasil', 'BR',
    'Iraq', 'IQ',
    'China', '中国', 'CN',
    'India', 'IN',
    'Indonesia', 'ID',
    'Pakistan', 'PK',
    'Bangladesh', 'BD',
    'Philippines', 'PH',
    'Thailand', 'TH'
  ].freeze

  ANALYTICS_CACHE_TTL = 10.minutes

  private

  # Cache key for one analytics section under the current filters. The page
  # auto-refreshes every 20 minutes; a 10-minute TTL keeps it current while
  # serving repeated loads (and the seven lazy sections) without re-running
  # the visit/event aggregations.
  def analytics_cache_key(section)
    [
      "analytics", section,
      params[:period] || "30", params[:custom_start_date].presence, params[:custom_end_date].presence,
      params[:filter_bots] != "false", params[:filter_geography] == "true"
    ]
  end

  def cached_analytics(section, &block)
    Rails.cache.fetch(analytics_cache_key(section), expires_in: ANALYTICS_CACHE_TTL, &block)
  end

  # Lazy-loaded section: runs the block (which sets the instance variables the
  # partial needs) and caches the rendered partial HTML.
  def render_cached_analytics_section(section, partial)
    html = cached_analytics(section) do
      yield
      render_to_string(partial: partial, layout: false)
    end
    render html: html.html_safe
  end

  def bot_visit?(user_agent)
    return false if user_agent.blank? # Don't treat missing user agents as bots
    BOT_PATTERNS.any? { |pattern| user_agent.match?(pattern) }
  end

  def filter_bot_visits(visits)
    # A direct predicate on the (already period-scoped) relation. The previous
    # `where.not(id: <unscoped subquery>)` regex-scanned all ~400k visits for
    # every KPI query (~5s each) and pushed the analytics page past Heroku's
    # 30s request timeout. Visits without a user agent are kept.
    visits.where("user_agent IS NULL OR user_agent !~* ?", BOT_PATTERNS.map(&:source).join('|'))
  end

  def filter_relevant_countries(visits)
    visits.where(country: RELEVANT_COUNTRIES)
  end

  def bot_country_visits(visits)
    visits.where(country: BOT_COUNTRIES)
  end

  def apply_analytics_filters(visits, options = {})
    filtered = visits

    # Apply bot filtering unless explicitly disabled
    unless options[:include_bots]
      filtered = filter_bot_visits(filtered)
    end

    # Apply geographic filtering if requested
    if options[:relevant_countries_only]
      filtered = filter_relevant_countries(filtered)
    end

    filtered
  end

  def calculate_period_dates
    period = params[:period] || '30'
    custom_start_date = params[:custom_start_date]
    custom_end_date = params[:custom_end_date]
    
    # Only use custom dates if period is explicitly 'custom' AND dates are actually present (not empty strings)
    if period == 'custom' && custom_start_date.to_s.strip.present? && custom_end_date.to_s.strip.present?
      start_date = Time.zone.parse(custom_start_date).beginning_of_day
      end_date = Time.zone.parse(custom_end_date).end_of_day
    else
      # Use preset periods - ignore any custom date values
      end_date = Time.zone.now.end_of_day
      start_date = case period
                   when 'today' then end_date.beginning_of_day
                   when '3' then (end_date - 3.days).beginning_of_day
                   when '7' then (end_date - 7.days).beginning_of_day
                   when '30' then (end_date - 30.days).beginning_of_day
                   when '90' then (end_date - 90.days).beginning_of_day
                   else (end_date - 30.days).beginning_of_day
                   end
    end
    
    { start_date: start_date, end_date: end_date }
  end
end
