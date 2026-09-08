require "json"
require "net/http"
require "uri"

namespace :seo do
  desc "Audit every URL in the sitemap. rake seo:audit (local, no server needed) or rake seo:audit[https://www.spinalcare.ro]"
  task :audit, [:host] => :environment do |_t, args|
    require "nokogiri"
    auditor = SeoAudit.new(args[:host].presence)
    exit(auditor.run ? 0 : 1)
  end
end

# Fetches the sitemap, requests each URL and reports SEO defects per page.
class SeoAudit
  TITLE_RANGE = (25..65)
  DESCRIPTION_RANGE = (70..165)

  Page = Struct.new(:url, :status, :redirected_to, :title, :description, :h1_count, :canonical,
                    :breadcrumb_count, :invalid_json_ld, :issues, keyword_init: true)

  def initialize(host)
    @host = host
    @session = nil
    unless host
      @session = ActionDispatch::Integration::Session.new(Rails.application)
      @session.host! "localhost"
    end
  end

  def run
    urls = sitemap_urls
    puts "Auditing #{urls.size} URLs from #{@host || 'local'}/sitemap.xml"
    pages = urls.map { |url| audit(url) }
    detect_duplicates(pages)

    problems = pages.reject { |p| p.issues.empty? }
    puts
    if problems.any?
      puts "Pages with issues (#{problems.size}):"
      problems.each do |p|
        puts "  #{p.url.sub(%r{\Ahttps?://[^/]+}, '')}"
        p.issues.each { |i| puts "    - #{i}" }
      end
    end
    puts
    puts "Summary: #{pages.size - problems.size} clean / #{pages.size} total"
    problems.empty?
  end

  private

  def sitemap_urls
    body = fetch("#{origin}/sitemap.xml").body
    Nokogiri::XML(body).remove_namespaces!.xpath("//url/loc").map(&:text)
  end

  def origin
    @host || "http://localhost"
  end

  # Follows redirects manually so we can report them. Returns [final_response, redirected_to].
  def fetch(url, limit = 5)
    if @session
      @session.get(url.sub(%r{\Ahttps?://[^/]+}, ""))
      @session.response
    else
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 60) do |http|
        http.get(uri.request_uri, { "User-Agent" => "seo-audit/1.0" })
      end
    end
  end

  def status_of(response) = @session ? response.status : response.code.to_i
  def location_of(response) = @session ? response.location : response["location"]
  def body_of(response) = response.body.to_s

  def audit(url)
    page = Page.new(url: url, issues: [], invalid_json_ld: 0, breadcrumb_count: 0, h1_count: 0)
    response = fetch(url)
    page.status = status_of(response)
    final_url = url
    hops = 0
    while [301, 302, 307, 308].include?(page.status) && hops < 5
      final_url = URI.join(final_url, location_of(response)).to_s
      page.redirected_to = final_url
      response = fetch(final_url)
      page.status = status_of(response)
      hops += 1
    end
    page.issues << "redirect -> #{page.redirected_to} (sitemap should list final URLs)" if page.redirected_to
    unless page.status == 200
      page.issues << "HTTP #{page.status}"
      return page
    end

    doc = Nokogiri::HTML(body_of(response))
    page.title = doc.at("title")&.text.to_s.squish
    page.description = doc.at("meta[name=description]")&.[]("content").to_s.squish
    page.h1_count = doc.css("h1").size
    page.canonical = doc.at("link[rel=canonical]")&.[]("href")
    page.breadcrumb_count = 0
    doc.css("script[type='application/ld+json']").each do |node|
      data = JSON.parse(node.text)
      page.breadcrumb_count += 1 if data["@type"] == "BreadcrumbList"
    rescue JSON::ParserError
      page.invalid_json_ld += 1
    end

    check(page, final_url)
    page
  end

  def check(page, final_url)
    t = page.title.length
    d = page.description.length
    page.issues << "title #{t} chars (want #{TITLE_RANGE}): #{page.title.inspect}" unless TITLE_RANGE.cover?(t)
    page.issues << "title lacks \"Bacău\": #{page.title.inspect}" unless page.title.include?("Bacău")
    page.issues << "description #{d} chars (want #{DESCRIPTION_RANGE}): #{page.description.inspect}" unless DESCRIPTION_RANGE.cover?(d)
    page.issues << "h1 count #{page.h1_count}" unless page.h1_count == 1
    expected_canonical = canonical_for(final_url)
    page.issues << "canonical #{page.canonical.inspect} != #{expected_canonical}" unless page.canonical == expected_canonical
    page.issues << "#{page.breadcrumb_count} BreadcrumbList blocks" if page.breadcrumb_count > 1
    page.issues << "#{page.invalid_json_ld} invalid JSON-LD block(s)" if page.invalid_json_ld.positive?
  end

  def canonical_for(url)
    path = URI(url).path.sub(%r{/+\z}, "")
    path = "/" if path.empty?
    "#{Rails.application.config.x.canonical_origin}#{path}"
  end

  def detect_duplicates(pages)
    ok = pages.select { |p| p.status == 200 }
    %i[title description].each do |field|
      ok.group_by { |p| p.public_send(field) }.each do |value, group|
        next if group.size < 2 || value.blank?
        group.each { |p| p.issues << "duplicate #{field} (#{group.size} pages): #{value.inspect[0, 60]}" }
      end
    end
  end
end
