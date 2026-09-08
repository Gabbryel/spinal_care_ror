# Resolves URLs that no longer exist to their current equivalent, so they can
# be answered with a 301 instead of a soft 404. Sources, in order:
#
# 1. config/legacy_redirects.yml — hand-maintained map of old pages.
# 2. Structural repairs — paths produced by the site's own former relative
#    links ("/echipa/specialitati-medicale", "/specialitati-medicale/
#    specialitati-medicale/imagistica", "/../echipa/x"): the longest suffix
#    that is a valid public path wins.
# 3. Root-level slugs from the old site ("/imagistica", "/nutri-ie"): looked
#    up as specialty, team member or patient-info slug, including retired
#    slugs recorded in slug_redirects.
#
# Returns the target path (or absolute URL) or nil when nothing matches.
class LegacyRedirect
  TOP_LEVEL = %w[echipa specialitati-medicale servicii-medicale info-pacient-index promotii cariere consum].freeze
  SLUGGED = {
    "specialitati-medicale" => Specialty,
    "servicii-medicale" => Specialty,
    "echipa" => Member,
    "info-pacient" => Fact
  }.freeze
  PUBLIC_PREFIX = { Specialty => "/specialitati-medicale", Member => "/echipa", Fact => "/info-pacient" }.freeze

  def self.static_map
    @static_map ||= YAML.load_file(Rails.root.join("config/legacy_redirects.yml")).to_h.freeze
  end

  def self.resolve(path)
    new(path).resolve
  end

  def initialize(path)
    @path = path.to_s.split("?").first.to_s.sub(%r{/+\z}, "")
    @path = "/" if @path.empty?
  end

  def resolve
    target = self.class.static_map[@path] || structural_target || root_slug_target
    target unless target.nil? || target == @path
  end

  private

  def segments
    @segments ||= @path.split("/").reject { |s| s.empty? || s == ".." || s == "." }
  end

  # Longest suffix of the path that is a real public path.
  def structural_target
    return if segments.size < 2

    (0...segments.size).each do |i|
      candidate = public_path_for(segments[i..])
      return candidate if candidate
    end
    nil
  end

  def public_path_for(parts)
    case parts.size
    when 1
      "/#{parts.first}" if TOP_LEVEL.include?(parts.first)
    when 2
      klass = SLUGGED[parts.first]
      klass && slugged_path(klass, parts.last)
    end
  end

  def root_slug_target
    return unless segments.size == 1

    [Specialty, Member, Fact].each do |klass|
      target = slugged_path(klass, segments.first)
      return target if target
    end
    nil
  end

  # "/prefix/<current slug>" for an existing or renamed slug, else nil.
  def slugged_path(klass, slug)
    current = klass.exists?(slug: slug) ? slug : SlugRedirect.lookup(klass, slug)&.new_slug
    return unless current
    return if klass == Member && !Member.exists?(slug: current, is_active: true)

    "#{PUBLIC_PREFIX[klass]}/#{current}"
  end
end
