class ErrorsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_after_action :log_action_view
  # Probes for .js/.json paths would otherwise trip the cross-origin JS check (422).
  skip_after_action :verify_same_origin_request
  before_action :skip_authorization

  # File extensions, dot-segments (/.env, /.git/config) and WordPress/CGI
  # probe prefixes: scanners, not people. They get a bodyless 404.
  FILE_LIKE = %r{\.[a-z0-9]{1,5}\z|/\.|/wp-|/cgi-bin/|/xmlrpc}i

  # Catch-all route. Old URLs with a current equivalent get a 301; everything
  # else is a real 404 (a bare one for file-like probes such as /wp-login.php,
  # a helpful page for everything else). Never a redirect to the homepage:
  # Google reads that as a soft 404 and keeps crawling the dead URL.
  def not_found
    if (target = LegacyRedirect.resolve(request.path))
      target = "#{target}?#{request.query_string}" if request.query_string.present? && !target.start_with?("http")
      return redirect_to target, status: :moved_permanently, allow_other_host: true
    end

    return head :not_found, content_type: "text/plain" if request.path.match?(FILE_LIKE) || wants_non_html?

    render_not_found
  end

  private

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
