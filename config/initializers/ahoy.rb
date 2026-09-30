class Ahoy::Store < Ahoy::DatabaseStore
  ORIGIN_COOKIE = "consent_origin".freeze

  # A visit can only start once the visitor accepts cookies, and accepting
  # reloads the page, so the request Ahoy sees names our own page as referrer
  # and whatever page the visitor was on as landing page. gdpr_controller.js
  # leaves the real referrer and landing page in a one-minute cookie; use them
  # (and the utm_* tags of the real landing page) for the visit it opens.
  def track_visit(data)
    super(data.merge(consent_origin))
  end

  private

  def consent_origin
    raw = request&.cookies&.[](ORIGIN_COOKIE)
    return {} if raw.blank?

    request.cookie_jar.delete(ORIGIN_COOKIE)
    origin = JSON.parse(raw)
    referrer = web_url(origin["referrer"])
    landing = web_url(origin["landing_page"])
    return {} unless landing && URI.parse(landing).host == request.host

    query = CGI.parse(URI.parse(landing).query.to_s)
    utm = %w[utm_source utm_medium utm_term utm_content utm_campaign].to_h { |k| [k.to_sym, query[k]&.first] }
    { referrer: referrer, referring_domain: referrer && URI.parse(referrer).host, landing_page: landing }.merge(utm)
  rescue JSON::ParserError, URI::InvalidURIError
    {}
  end

  def web_url(value)
    value if value.is_a?(String) && value.length <= 2048 && value.match?(%r{\Ahttps?://}i)
  end
end

# set to true for JavaScript tracking
Ahoy.api = true

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = true
