# Visitor-behaviour analyses for the "Parcurs & Comportament" analytics
# section. Works on a filtered Ahoy::Visit relation for one period plus the
# events of those visits. Every method returns plain hashes/arrays for the
# partial; heavy grouping is done in SQL, the last mile in Ruby.
class BehaviourAnalytics
  CONVERSION = %w[call booking].freeze
  WEEKDAYS = %w[Duminică Luni Marți Miercuri Joi Vineri Sâmbătă].freeze

  def initialize(visits:, start_date:, end_date:)
    @visits = visits
    @start_date = start_date
    @end_date = end_date
  end

  # ---------------------------------------------------------------- shared

  def visit_ids_sql
    @visits.select(:id).to_sql
  end

  def total_visits
    @total_visits ||= @visits.count
  end

  def conversion_visit_ids
    @conversion_visit_ids ||= Ahoy::Event.where(name: '$click').where("properties->>'category' IN (?)", CONVERSION)
                                         .where("visit_id IN (#{visit_ids_sql})").distinct.pluck(:visit_id).to_set
  end

  def local
    @local ||= "((time AT TIME ZONE 'UTC') AT TIME ZONE '#{Time.zone.tzinfo.name}')"
  end

  # 1. The last three pages before the first contact click, as sequences.
  def paths_to_contact
    rows = select_all(<<~SQL)
      WITH conv AS (
        SELECT visit_id, MIN(time) AS t FROM ahoy_events
        WHERE name = '$click' AND properties->>'category' IN ('call','booking') AND visit_id IN (#{visit_ids_sql})
        GROUP BY visit_id
      ), v AS (
        SELECT e.visit_id, #{path_sql("e.properties->>'url'")} AS p, e.time,
               row_number() OVER (PARTITION BY e.visit_id ORDER BY e.time DESC) AS rn
        FROM ahoy_events e JOIN conv ON conv.visit_id = e.visit_id
        WHERE e.name = '$view' AND e.time <= conv.t
      )
      SELECT visit_id, string_agg(p, ' → ' ORDER BY rn DESC) AS path FROM v WHERE rn <= 3 GROUP BY visit_id
    SQL
    rows.group_by { |r| r['path'].to_s.split(' → ').map { |p| p == '/' ? 'Homepage' : p }.join(' → ') }
        .map { |path, rs| { path: path, count: rs.size } }.sort_by { |r| -r[:count] }.first(10)
  end

  # 2. Seconds from the first page view to the first contact click, and how
  #    many pages were seen before it.
  def decision_time
    rows = select_all(<<~SQL)
      WITH conv AS (
        SELECT visit_id, MIN(time) AS t FROM ahoy_events
        WHERE name = '$click' AND properties->>'category' IN ('call','booking') AND visit_id IN (#{visit_ids_sql})
        GROUP BY visit_id
      )
      SELECT conv.visit_id,
             EXTRACT(EPOCH FROM (conv.t - MIN(e.time)))::int AS seconds,
             COUNT(*) AS pages
      FROM conv JOIN ahoy_events e ON e.visit_id = conv.visit_id AND e.name = '$view' AND e.time <= conv.t
      GROUP BY conv.visit_id, conv.t
    SQL
    return nil if rows.empty?
    seconds = rows.map { |r| r['seconds'].to_i }.sort
    pages = rows.map { |r| r['pages'].to_i }
    {
      conversions: rows.size,
      median_seconds: percentile(seconds, 0.5), p25: percentile(seconds, 0.25), p75: percentile(seconds, 0.75),
      under_minute_share: pct(seconds.count { |s| s < 60 }, seconds.size),
      pages_before: { '1' => pages.count(1), '2' => pages.count(2), '3' => pages.count(3), '4+' => pages.count { |n| n >= 4 } }
    }
  end

  # 3. Google landing pages: what people click next and how often they convert.
  def landing_intent
    google = @visits.where("referring_domain ILIKE '%google%'")
    ids = google.pluck(:id)
    return [] if ids.empty?
    landings = google.group(:landing_page).count.each_with_object(Hash.new(0)) { |(lp, n), h| h[path_of(lp)] += n }
    first_clicks = select_all(<<~SQL)
      SELECT DISTINCT ON (v.id) #{path_sql('v.landing_page')} AS landing,
             COALESCE(NULLIF(e.properties->>'text', ''), e.properties->>'destination') AS step
      FROM ahoy_visits v JOIN ahoy_events e ON e.visit_id = v.id AND e.name = '$click'
      WHERE v.id IN (#{ids.join(',')})
      ORDER BY v.id, e.time
    SQL
    steps = first_clicks.group_by { |r| r['landing'] }.transform_values { |rs| rs.group_by { |r| r['step'].to_s.squish.truncate(40) }.max_by { |_, g| g.size }&.first }
    conv_by_landing = google.where(id: conversion_visit_ids.to_a).group(:landing_page).count.each_with_object(Hash.new(0)) { |(lp, n), h| h[path_of(lp)] += n }
    landings.sort_by { |_, n| -n }.first(10).map do |landing, n|
      { landing: landing, visits: n, next_step: steps[landing], conversion_rate: pct(conv_by_landing[landing], n) }
    end
  end

  # 4. Returning visitors: share, days between visits, conversion first vs return.
  def returning
    return nil if total_visits.zero?
    rows = select_all(<<~SQL)
      SELECT v.id, v.visitor_token,
             EXISTS (SELECT 1 FROM ahoy_visits p WHERE p.visitor_token = v.visitor_token AND p.started_at < v.started_at) AS returning,
             EXTRACT(EPOCH FROM (v.started_at - (SELECT MAX(p.started_at) FROM ahoy_visits p WHERE p.visitor_token = v.visitor_token AND p.started_at < v.started_at)))/86400 AS days_since
      FROM ahoy_visits v WHERE v.id IN (#{visit_ids_sql})
    SQL
    ret = rows.select { |r| r['returning'] == true || r['returning'] == 't' }
    first = rows - ret
    gaps = ret.map { |r| r['days_since'].to_f }.compact.sort
    {
      visits: rows.size, returning_visits: ret.size, returning_share: pct(ret.size, rows.size),
      median_days_between: gaps.empty? ? nil : percentile(gaps, 0.5).round(1),
      rate_first: pct(first.count { |r| conversion_visit_ids.include?(r['id'].to_i) }, first.size),
      rate_returning: pct(ret.count { |r| conversion_visit_ids.include?(r['id'].to_i) }, ret.size)
    }
  end

  # 5. Doctor profile pages: who gets viewed, from where, and whether a profile
  #    view goes with a contact click.
  def doctor_funnel
    return nil if total_visits.zero?
    profile_views = Ahoy::Event.where(name: '$view').where("visit_id IN (#{visit_ids_sql})")
                               .where("properties->>'url' ~ '/echipa/[^/?#]+'")
    with_profile = profile_views.distinct.pluck(:visit_id).to_set
    return nil if with_profile.empty?
    top = profile_views.group(Arel.sql(path_sql("properties->>'url'"))).order('count_all DESC').limit(8).count
    from = select_all(<<~SQL)
      WITH v AS (
        SELECT visit_id, #{path_sql("properties->>'url'")} AS p,
               lag(#{path_sql("properties->>'url'")}) OVER (PARTITION BY visit_id ORDER BY time) AS prev
        FROM ahoy_events WHERE name = '$view' AND visit_id IN (#{visit_ids_sql})
      )
      SELECT prev, COUNT(*) AS n FROM v WHERE p ~ '^/echipa/.+' AND prev IS NOT NULL AND prev !~ '^/echipa/.+' GROUP BY prev ORDER BY n DESC LIMIT 5
    SQL
    without = total_visits - with_profile.size
    {
      profile_visits: with_profile.size, share: pct(with_profile.size, total_visits),
      rate_with: pct((with_profile & conversion_visit_ids).size, with_profile.size),
      rate_without: pct((conversion_visit_ids - with_profile).size, without),
      top_profiles: top.to_a, from_pages: from.map { |r| [r['prev'], r['n'].to_i] }
    }
  end

  # 6. Visits that click around a lot and never contact; where non-converting
  #    visits leave from.
  def dead_ends
    return nil if total_visits.zero?
    nav_counts = Ahoy::Event.where(name: '$click').where("properties->>'category' = 'nav'").where("visit_id IN (#{visit_ids_sql})")
                            .group(:visit_id).count
    looping = nav_counts.select { |vid, n| n >= 5 && !conversion_visit_ids.include?(vid) }
    exits = select_all(<<~SQL)
      SELECT DISTINCT ON (visit_id) visit_id, COALESCE(NULLIF(properties->>'section', ''), 'necunoscut') AS section
      FROM ahoy_events WHERE name = '$click' AND visit_id IN (#{visit_ids_sql}) ORDER BY visit_id, time DESC
    SQL
    exit_sections = exits.reject { |r| conversion_visit_ids.include?(r['visit_id'].to_i) }.group_by { |r| r['section'] }
                         .map { |sec, rs| [sec, rs.size] }.sort_by { |_, n| -n }
    { looping_visits: looping.size, share: pct(looping.size, total_visits), exit_sections: exit_sections }
  end

  # 7. Everything by device.
  def devices
    by_device = @visits.group(:device_type).count
    views = Ahoy::Event.where(name: '$view').where("visit_id IN (#{visit_ids_sql})")
                       .joins('INNER JOIN ahoy_visits ON ahoy_visits.id = ahoy_events.visit_id').group('ahoy_visits.device_type').count
    conv = Ahoy::Event.where(name: '$click').where("properties->>'category' IN (?)", CONVERSION).where("visit_id IN (#{visit_ids_sql})")
                      .joins('INNER JOIN ahoy_visits ON ahoy_visits.id = ahoy_events.visit_id')
                      .group('ahoy_visits.device_type', Arel.sql("properties->>'category'")).count
    by_device.sort_by { |_, n| -n }.first(4).map do |device, n|
      calls = conv[[device, 'call']] || 0
      bookings = conv[[device, 'booking']] || 0
      { device: device.presence || 'necunoscut', visits: n, views_per_visit: n.positive? ? ((views[device] || 0).to_f / n).round(1) : 0,
        per_100: pct(calls + bookings, n), calls: calls, bookings: bookings }
    end
  end

  # 8. Contact clicks by weekday and hour (local time): a 7×24 grid + top slots.
  def heat
    counts = Ahoy::Event.where(name: '$click').where("properties->>'category' IN (?)", CONVERSION).where("visit_id IN (#{visit_ids_sql})")
                        .group(Arel.sql("EXTRACT(DOW FROM #{local})::int"), Arel.sql("EXTRACT(HOUR FROM #{local})::int")).count
    return nil if counts.empty?
    grid = Array.new(7) { Array.new(24, 0) }
    counts.each { |(dow, hour), n| grid[dow][hour] = n }
    top = counts.sort_by { |_, n| -n }.first(5).map { |(dow, hour), n| { day: WEEKDAYS[dow], hour: hour, count: n } }
    { grid: grid, max: counts.values.max, top: top, total: counts.values.sum }
  end

  # 9. Tagged campaign traffic.
  def campaigns
    tagged = @visits.where.not(utm_source: [nil, ''])
    return [] if tagged.none?
    conv = tagged.where(id: conversion_visit_ids.to_a).group(:utm_source, :utm_medium, :utm_campaign).count
    tagged.group(:utm_source, :utm_medium, :utm_campaign).order('count_all DESC').limit(10).count.map do |(source, medium, campaign), n|
      { source: source, medium: medium, campaign: campaign, visits: n, conversions: conv[[source, medium, campaign]] || 0 }
    end
  end

  # 10. Time on page, scroll depth, and whether the contact row was seen.
  def engagement
    rows = select_all(<<~SQL)
      WITH per_view AS (
        SELECT visit_id, properties->>'page' AS page,
               SUM((properties->>'seconds')::int) AS seconds,
               MAX((properties->>'depth')::int) AS depth,
               BOOL_OR((properties->>'cta_present')::boolean) AS cta_present,
               BOOL_OR((properties->>'cta_seen')::boolean) AS cta_seen
        FROM ahoy_events WHERE name = '$leave' AND visit_id IN (#{visit_ids_sql}) GROUP BY visit_id, properties->>'page'
      )
      SELECT page, COUNT(*) AS n, AVG(seconds)::int AS avg_seconds, AVG(depth)::int AS avg_depth,
             SUM(CASE WHEN cta_present THEN 1 ELSE 0 END) AS with_cta,
             SUM(CASE WHEN cta_present AND cta_seen THEN 1 ELSE 0 END) AS saw_cta
      FROM per_view GROUP BY page HAVING COUNT(*) >= 5 ORDER BY n DESC LIMIT 12
    SQL
    rows.map do |r|
      { page: path_of(r['page']), views: r['n'].to_i, avg_seconds: r['avg_seconds'].to_i, avg_depth: r['avg_depth'].to_i,
        cta_seen_share: r['with_cta'].to_i.positive? ? pct(r['saw_cta'].to_i, r['with_cta'].to_i) : nil }
    end
  end

  # 11. Booking modal opens vs steps reported by the booking site.
  def booking_funnel
    opens = Ahoy::Event.where(name: '$click').where("properties->>'category' = 'booking'").where("visit_id IN (#{visit_ids_sql})").count
    steps = Ahoy::Event.where(name: '$booking').where("visit_id IN (#{visit_ids_sql})").group(Arel.sql("properties->>'step'")).count
    { opens: opens, started: steps['started'] || 0, completed: steps['completed'] || 0, reporting: steps.any? }
  end

  # 12. tel: clicks per day next to the calls reception counted.
  def call_tally
    clicks = Ahoy::Event.where(name: '$click').where("properties->>'category' = 'call'").where("visit_id IN (#{visit_ids_sql})")
                        .group(Arel.sql("DATE(#{local})")).count
    tallies = CallTally.where(date: @start_date.to_date..@end_date.to_date).index_by(&:date)
    days = (tallies.keys + clicks.keys).uniq.sort.reverse.first(14)
    rows = days.map { |d| { date: d, clicks: clicks[d] || 0, calls: tallies[d]&.calls } }
    with_both = rows.select { |r| r[:calls] }
    ratio = with_both.sum { |r| r[:clicks] }.positive? ? (with_both.sum { |r| r[:calls] }.to_f / with_both.sum { |r| r[:clicks] }).round(2) : nil
    { rows: rows, ratio: ratio, days_with_tally: with_both.size }
  end

  # 13. What people type into the team search, and what finds nothing.
  def search_terms
    Ahoy::Event.where(name: '$search').where("visit_id IN (#{visit_ids_sql})")
               .group(Arel.sql("lower(properties->>'term')")).order('count_all DESC').limit(15).count.map do |term, n|
      zero = Ahoy::Event.where(name: '$search').where("visit_id IN (#{visit_ids_sql})")
                        .where("lower(properties->>'term') = ? AND (properties->>'results')::int = 0", term).count
      { term: term, count: n, zero: zero }
    end
  end

  # 14. Price list: sections scrolled into view, and "Sună pentru preț" taps by service.
  def price_list
    sections = Ahoy::Event.where(name: '$section_view').where("visit_id IN (#{visit_ids_sql})")
                          .group(Arel.sql("properties->>'section'")).order('count_all DESC').limit(12).count.to_a
    labels = Ahoy::Event.where(name: '$click').where("properties->>'category' = 'call' AND properties->>'label' IS NOT NULL")
                        .where("visit_id IN (#{visit_ids_sql})").group(Arel.sql("properties->>'label'")).order('count_all DESC').limit(10).count.to_a
    { sections: sections, call_for_price: labels }
  end

  # 15. Dead links reached by people, with the pages that sent them.
  def not_found
    events = Ahoy::Event.where(name: '$not_found').where('time >= ? AND time <= ?', @start_date, @end_date)
    events.group(Arel.sql("properties->>'path'")).order('count_all DESC').limit(10).count.map do |path, n|
      referers = events.where("properties->>'path' = ?", path).where("properties->>'referer' IS NOT NULL")
                       .group(Arel.sql("properties->>'referer'")).order('count_all DESC').limit(3).count.keys.map { |r| r.to_s.sub(%r{\Ahttps?://(www\.)?}, '').truncate(60) }
      { path: path, count: n, referers: referers }
    end
  end

  private

  def select_all(sql)
    Ahoy::Event.connection.select_all(sql).to_a
  end

  def path_sql(expr)
    "COALESCE(NULLIF(regexp_replace(regexp_replace(#{expr}, '^https?://[^/]+', ''), '[?#].*$', ''), ''), '/')"
  end

  def path_of(url)
    path = url.to_s.sub(%r{\Ahttps?://[^/]+}, '').sub(/[?#].*\z/, '')
    path.blank? || path == '/' ? 'Homepage' : path
  end

  def pct(a, b)
    b.to_i.positive? ? (a.to_f * 100 / b).round(1) : 0.0
  end

  def percentile(sorted, p)
    return 0 if sorted.empty?
    sorted[[(sorted.size * p).ceil - 1, 0].max]
  end
end
