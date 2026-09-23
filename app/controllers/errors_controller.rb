class ErrorsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_after_action :log_action_view
  # Probes for .js/.json paths would otherwise trip the cross-origin JS check (422).
  skip_after_action :verify_same_origin_request
  before_action :skip_authorization

  # File extensions, dot-segments (/.env, /.git/config) and WordPress/CGI
  # probe prefixes: scanners, not people. They get a bodyless 404.
  FILE_LIKE = %r{\.[a-z0-9]{1,5}\z|/\.|/wp-|/cgi-bin/|/xmlrpc}i

  # Single-segment roots that only vulnerability scanners ask for: archive
  # years, other-CMS roots and bare language codes. They arrive with the site
  # itself as referer (spinalcare.ro/2024/ → /2024), so they used to be
  # tracked as dead links and each one opened a visit with no page view.
  # Paths a person could plausibly type (/contact, /blog, /preturi) are not
  # here: those still get the helpful 404 page and stay in the report.
  PROBE_PATHS = %r{\A/(20\d\d|backup|content|cms|wordpress|blog\d+|old|new|test|demo|site|shop|store|
                       admin|administrator|phpmyadmin|sql|db|vendor|[a-z]{2})/?\z}xi

  # Catch-all route. Old URLs with a current equivalent get a 301; everything
  # else is a real 404 (a bare one for file-like probes such as /wp-login.php,
  # a helpful page for everything else). Never a redirect to the homepage:
  # Google reads that as a soft 404 and keeps crawling the dead URL.
  def not_found
    if (target = LegacyRedirect.resolve(request.path))
      target = "#{target}?#{request.query_string}" if request.query_string.present? && !target.start_with?("http")
      return redirect_to target, status: :moved_permanently, allow_other_host: true
    end

    if request.path.match?(FILE_LIKE) || request.path.match?(PROBE_PATHS) || wants_non_html?
      return head :not_found, content_type: "text/plain"
    end

    track_not_found
    render_not_found
  end

  private

  # Dead links reached by people (Ahoy drops bots) show up in the analytics
  # "Parcurs & Comportament" section with the page that linked to them.
  def track_not_found
    ahoy.track("$not_found", path: request.path.to_s.first(200), referer: request.referer.to_s.first(300).presence)
  rescue StandardError => e
    Rails.logger.warn "not_found tracking failed: #{e.message}"
  end

  # Only an explicit non-HTML format (JSON, XML, JS…) gets the bare 404.
  # "Accept: */*" (curl, many crawlers) is not a request for something else.
  def wants_non_html?
    format = request.format
    format.present? && !format.html? && format != Mime::ALL
  end

  public

  def internal_server_error
    render "errors/internal_server_error", status: :internal_server_error
  end
end
