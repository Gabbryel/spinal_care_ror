module SeoHelper
  # Absolute origin every public URL is canonicalised to (https://www.spinalcare.ro).
  def canonical_origin
    Rails.application.config.x.canonical_origin
  end

  # Self-referential canonical URL for the current request: canonical host, no query
  # string, no trailing slash (except for the root). Views can override it with
  # `content_for :canonical_url, "https://www.spinalcare.ro/..."` (paginated or
  # duplicate pages).
  def canonical_url
    return content_for(:canonical_url) if content_for?(:canonical_url)

    canonical_url_for(request.path)
  end

  # Builds a canonical absolute URL from a path.
  def canonical_url_for(path)
    normalized = path.to_s.split("?").first.to_s.sub(%r{/+\z}, "")
    normalized = "/#{normalized}" unless normalized.start_with?("/")
    normalized == "/" ? "#{canonical_origin}/" : "#{canonical_origin}#{normalized}"
  end
end
