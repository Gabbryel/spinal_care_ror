# Shared 404 handling for the public controllers: retired slugs 301, paths
# built from old relative links 301, and a real 404 page for the rest
# (with "did you mean" suggestions when the controller has some).
module NotFoundRendering
  extend ActiveSupport::Concern

  private

  def redirect_legacy_path
    target = LegacyRedirect.resolve(request.path)
    return false unless target

    target = "#{target}?#{request.query_string}" if request.query_string.present? && !target.start_with?("http")
    redirect_to target, status: :moved_permanently, allow_other_host: true
    true
  end

  def render_not_found(suggestions_template = nil, suggestions: [])
    @specialties = Specialty.where(is_active: true).order(name: :asc) unless defined?(@specialties) && @specialties
    if suggestions_template && suggestions.any?
      render suggestions_template, status: :not_found
    else
      render "errors/not_found", status: :not_found
    end
  end
end
