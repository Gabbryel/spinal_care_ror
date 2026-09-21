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

  # Traffic channel of a visit, from what the landing URL and referrer carry.
  # Google Ads auto-tagging adds gclid/gbraid/wbraid (certain); Bing adds
  # msclkid; other paid traffic needs utm_medium=cpc/paid…; fbclid marks a
  # Facebook/Instagram link, paid or not. `prefix` qualifies the columns
  # when the visits table is joined ("ahoy_visits.").
  def self.channel_sql(prefix = '')
    lp = "#{prefix}landing_page"
    rd = "#{prefix}referring_domain"
    um = "#{prefix}utm_medium"
    us = "#{prefix}utm_source"
    <<~SQL.squish
      CASE
        WHEN #{lp} ~* '[?&](gclid|gbraid|wbraid)=' THEN 'paid_google'
        WHEN #{lp} ~* '[?&]msclkid=' THEN 'paid_other'
        WHEN #{um} ~* '^(cpc|ppc|paid|paidsocial|paid_social|paid-social|display|ads?)$'
          THEN CASE WHEN #{us} ~* 'google' THEN 'paid_google' ELSE 'paid_other' END
        WHEN #{rd} ~* 'google|bing|yahoo|duckduckgo|yandex' THEN 'organic_search'
        WHEN #{rd} ~* 'facebook|instagram|fb\\.|tiktok|linkedin|youtube'
          OR #{us} ~* '^(facebook|instagram|ig|fb)$' OR #{lp} ~* '[?&]fbclid=' THEN 'social'
        WHEN #{rd} ~* 'spinalcare\\.ro|^77\\.81\\.2\\.98$' THEN 'self'
        WHEN #{rd} IS NULL OR #{rd} = '' THEN 'direct'
        ELSE 'referral'
      END
    SQL
  end

  CHANNEL_LABELS = {
    'paid_google' => 'Google Ads',
    'paid_other' => 'Alte reclame (UTM)',
    'organic_search' => 'Căutare organică',
    'social' => 'Social (Facebook, Instagram)',
    'direct' => 'Direct',
    'referral' => 'Alte site-uri',
    'self' => 'Site propriu'
  }.freeze

  # Options of the "Canal" filter: group name => channels.
  CHANNEL_FILTERS = {
    'paid' => %w[paid_google paid_other],
    'organic' => %w[organic_search],
    'social' => %w[social],
    'direct' => %w[direct],
    'paid_google' => %w[paid_google],
    'referral' => %w[referral self]
  }.freeze

  CHANNEL_FILTER_LABELS = {
    'paid' => 'Plătit (reclame)',
    'organic' => 'Organic (căutare)',
    'social' => 'Social',
    'direct' => 'Direct',
    'paid_google' => 'Doar Google Ads',
    'referral' => 'Alte site-uri + site propriu'
  }.freeze

  private

  # Cache key for one analytics section under the current filters. The page
  # auto-refreshes every 20 minutes; a 10-minute TTL keeps it current while
  # serving repeated loads (and the seven lazy sections) without re-running
  # the visit/event aggregations.
  def analytics_cache_key(section)
    [
      "analytics", section,
      params[:period] || "30", params[:custom_start_date].presence, params[:custom_end_date].presence,
      params[:filter_bots] != "false", params[:filter_geography] == "true", params[:channel].presence
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

  def filter_channel(visits, channel)
    channels = CHANNEL_FILTERS[channel.to_s]
    return visits unless channels
    # The channel SQL contains "[?&]" regexes, so no "?" binds here: the
    # channel names are quoted into the statement.
    quoted = channels.map { |c| ActiveRecord::Base.connection.quote(c) }.join(', ')
    visits.where(Arel.sql("(#{AnalyticsFilterHelper.channel_sql}) IN (#{quoted})"))
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

    # Channel filter from the page's "Canal" select, unless a caller asks
    # for all channels (the paid-vs-organic section compares them).
    channel = options.key?(:channel) ? options[:channel] : params[:channel]
    filtered = filter_channel(filtered, channel) if channel.present? && channel != 'all'

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
