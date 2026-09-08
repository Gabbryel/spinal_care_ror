# 301 from a retired slug (see SlugRedirect) to the current one, keeping the
# rest of the path and the query string.
module SlugRedirectable
  extend ActiveSupport::Concern

  private

  def redirect_retired_slug(klass)
    old_slug = params[:id].to_s
    redirect = old_slug.present? && SlugRedirect.lookup(klass, old_slug)
    return false unless redirect

    path = request.path.sub(%r{/#{Regexp.escape(old_slug)}(?=/|\z)}, "/#{redirect.new_slug}")
    path = "#{path}?#{request.query_string}" if request.query_string.present?
    redirect_to path, status: :moved_permanently
    true
  end
end
