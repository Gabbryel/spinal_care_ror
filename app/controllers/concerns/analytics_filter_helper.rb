module AnalyticsFilterHelper
  extend ActiveSupport::Concern

  # Bot user agent patterns (common crawlers, scrapers, spam bots)
  BOT_PATTERNS = [
    /bot/i, /crawl/i, /spider/i, /slurp/i, /scraper/i,
    /headless/i, /phantom/i, /puppeteer/i, /selenium/i,
    /curl/i, /wget/i, /python/i, /java/i, /perl/i,
    /ahrefs/i, /semrush/i, /moz/i, /majestic/i, /dotbot/i,
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

  private

  def bot_visit?(user_agent)
    return false if user_agent.blank? # Don't treat missing user agents as bots
    BOT_PATTERNS.any? { |pattern| user_agent.match?(pattern) }
  end

  def filter_bot_visits(visits)
    # Only filter visits that have user agents matching bot patterns
    # Don't exclude visits with NULL user agents
    visits.where.not(
      id: Ahoy::Visit.where.not(user_agent: nil).where(
        "user_agent ~* ?",
        BOT_PATTERNS.map(&:source).join('|')
      ).select(:id)
    )
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
    
    if period == 'custom' && custom_start_date.present? && custom_end_date.present?
      start_date = Time.zone.parse(custom_start_date).beginning_of_day
      end_date = Time.zone.parse(custom_end_date).end_of_day
    else
      end_date = Time.zone.now
      start_date = case period
                   when 'today' then end_date.beginning_of_day
                   when '3' then 3.days.ago(end_date).beginning_of_day
                   when '7' then 7.days.ago(end_date).beginning_of_day
                   when '30' then 30.days.ago(end_date).beginning_of_day
                   when '90' then 90.days.ago(end_date).beginning_of_day
                   else 30.days.ago(end_date).beginning_of_day
                   end
    end
    
    { start_date: start_date, end_date: end_date }
  end
end
