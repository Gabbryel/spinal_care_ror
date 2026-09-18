# Rule-based audit and interpretation of the Ahoy analytics for one period.
#
# `audit` checks that the data can be trusted (tracking alive, duplicates,
# bots, geocoding, self-traffic...). `insights` turns the numbers into short
# Romanian sentences: trend, conversion rate, pages that convert or dead-end,
# sources, devices, geography, anomalies and timing.
#
# Every finding is a Finding with a level (bad, warn, info, ok), a title, a
# sentence with the numbers, and an optional hint on what to do.
class AnalyticsInsights
  Finding = Struct.new(:level, :title, :text, :hint, keyword_init: true)

  CONVERSION_CATEGORIES = %w[call booking].freeze
  SELF_REFERRER = 'spinalcare\.ro|^77\.81\.2\.98$'.freeze
  MIN_PAGE_VIEWS = 30 # a page needs this many views before we judge its conversion
  WEEKDAYS = %w[Duminică Luni Marți Miercuri Joi Vineri Sâmbătă].freeze
  SOURCE_BUCKETS = [
    ['Google', /google/i],
    ['Facebook', /facebook/i],
    ['Instagram', /instagram/i],
    ['Bing', /bing/i],
    ['Site propriu', /#{SELF_REFERRER}/i]
  ].freeze

  def initialize(visits:, prev_visits:, all_visits:, start_date:, end_date:, now: Time.zone.now)
    @visits = visits
    @prev_visits = prev_visits
    @all_visits = all_visits
    @start_date = start_date
    @end_date = end_date
    @now = now
  end

  def audit
    [tracking_alive, click_tracking_alive, visits_without_views, duplicate_views, bot_share,
     foreign_share, geocoding_coverage, concentrated_traffic, self_referrals, uncategorised_clicks].compact
  end

  def insights
    return [Finding.new(level: 'info', title: 'Date insuficiente',
                        text: 'Nu există vizite în perioada selectată, deci nu este nimic de interpretat.')] if total_visits.zero?

    [traffic_trend, conversion_rate, converting_pages, dead_end_pages, sources, devices, geography, anomalies, timing].compact
  end

  private

  # ---------------------------------------------------------------- scopes

  def views
    @views ||= Ahoy::Event.where(name: '$view').where(visit_id: @visits.select(:id))
  end

  def clicks
    @clicks ||= Ahoy::Event.where(name: '$click').where(visit_id: @visits.select(:id))
  end

  def conversion_clicks
    @conversion_clicks ||= clicks.where("properties->>'category' IN (?)", CONVERSION_CATEGORIES)
  end

  def prev_conversions
    @prev_conversions ||= Ahoy::Event.where(name: '$click').where(visit_id: @prev_visits.select(:id))
                                     .where("properties->>'category' IN (?)", CONVERSION_CATEGORIES)
  end

  def total_visits
    @total_visits ||= @visits.count
  end

  def unique_visitors
    @unique_visitors ||= @visits.distinct.count(:visitor_token)
  end

  def prev_total
    @prev_total ||= @prev_visits.count
  end

  def prev_unique
    @prev_unique ||= @prev_visits.distinct.count(:visitor_token)
  end

  def days_in_period
    [(@end_date.to_date - @start_date.to_date).to_i + 1, 1].max
  end

  # ---------------------------------------------------------------- audit

  def tracking_alive
    last_day = Ahoy::Event.where(name: '$view').where('time > ?', @now - 24.hours).count
    baseline = Ahoy::Event.where(name: '$view').where(time: (@now - 8.days)..(@now - 24.hours)).count / 7.0
    if last_day.zero?
      Finding.new(level: 'bad', title: 'Urmărirea vizualizărilor pare oprită',
                  text: 'Nicio vizualizare de pagină înregistrată în ultimele 24 de ore.',
                  hint: 'Verifică în consola browserului dacă ahoy.js se încarcă pe site și dacă /ahoy/events răspunde 200.')
    elsif baseline > 20 && last_day < baseline * 0.3
      Finding.new(level: 'warn', title: 'Vizualizări mult sub media zilnică',
                  text: "Doar #{fmt(last_day)} vizualizări în ultimele 24 de ore, față de o medie de #{fmt(baseline.round)} pe zi în săptămâna precedentă.",
                  hint: 'Poate fi o zi liberă sau o problemă de tracking; compară cu Google Search Console.')
    else
      Finding.new(level: 'ok', title: 'Urmărirea vizualizărilor funcționează',
                  text: "#{fmt(last_day)} vizualizări de pagină în ultimele 24 de ore (medie #{fmt(baseline.round)} pe zi în săptămâna precedentă).")
    end
  end

  def click_tracking_alive
    last_day_views = Ahoy::Event.where(name: '$view').where('time > ?', @now - 24.hours).count
    return nil if last_day_views.zero? # tracking_alive already reports this
    last_day_clicks = Ahoy::Event.where(name: '$click').where('time > ?', @now - 24.hours).count
    if last_day_views >= 50 && last_day_clicks.zero?
      Finding.new(level: 'bad', title: 'Click-urile nu se mai înregistrează',
                  text: "#{fmt(last_day_views)} vizualizări dar niciun click în ultimele 24 de ore.",
                  hint: 'Controller-ul click-tracker nu rulează; verifică bundle-ul JavaScript.')
    else
      Finding.new(level: 'ok', title: 'Urmărirea click-urilor funcționează',
                  text: "#{fmt(last_day_clicks)} click-uri la #{fmt(last_day_views)} vizualizări în ultimele 24 de ore.")
    end
  end

  def visits_without_views
    return nil if total_visits.zero?
    without = @visits.where.not(id: views.select(:visit_id)).count
    share = pct(without, total_visits)
    Finding.new(level: share > 40 ? 'warn' : 'info', title: 'Vizite fără nicio pagină vizualizată',
                text: "#{fmt(without)} din #{fmt(total_visits)} vizite (#{share}%) nu au nicio vizualizare de pagină.",
                hint: share > 40 ? 'Procent mare: ad-blockere, boți neidentificați (vezi „Trafic din afara zonei relevante”) sau vizitatori care pleacă înainte să se încarce scriptul. Vizitele sunt numărate, dar paginile și click-urile lor nu.' : 'Normal sub 20–30%: ad-blockere și vizite abandonate imediat.')
  end

  def duplicate_views
    return nil if total_visits.zero?
    row = Ahoy::Event.connection.select_one(<<~SQL)
      WITH v AS (
        SELECT visit_id, properties->>'url' AS url, time,
               lag(time) OVER (PARTITION BY visit_id, properties->>'url' ORDER BY time) AS prev
        FROM ahoy_events
        WHERE name = '$view' AND visit_id IN (#{@visits.select(:id).to_sql})
      )
      SELECT count(*) AS total,
             count(*) FILTER (WHERE prev IS NOT NULL AND time - prev < interval '3 seconds') AS dups
      FROM v
    SQL
    total = row['total'].to_i
    dups = row['dups'].to_i
    return nil if total.zero?
    share = pct(dups, total)
    Finding.new(level: share > 3 ? 'warn' : 'ok', title: 'Vizualizări duplicate',
                text: "#{fmt(dups)} din #{fmt(total)} vizualizări (#{share}%) sunt duplicate (aceeași pagină, aceeași vizită, sub 3 secunde).",
                hint: share > 3 ? 'Scriptul de tracking rula de mai multe ori pe pagină; problema a fost rezolvată pe 17 septembrie 2026, deci perioadele de după ar trebui să fie sub 1%.' : nil)
  end

  def bot_share
    all = @all_visits.count
    return nil if all.zero?
    bots = @all_visits.where('user_agent ~* ?', AnalyticsFilterHelper::BOT_PATTERNS.map(&:source).join('|')).count
    share = pct(bots, all)
    Finding.new(level: share > 40 ? 'warn' : 'info', title: 'Trafic de boți identificat',
                text: "#{fmt(bots)} din #{fmt(all)} vizite (#{share}%) vin de la crawlere cunoscute și sunt excluse când filtrul de boți este activ.",
                hint: share > 40 ? 'Peste 40% boți: verifică secțiunea „Trafic Bot & Spam” pentru agenți noi de adăugat la listă.' : nil)
  end

  def foreign_share
    with_country = @visits.where.not(country: [nil, ''])
    n = with_country.count
    return nil if n.zero?
    foreign = with_country.where.not(country: AnalyticsFilterHelper::RELEVANT_COUNTRIES)
    f = foreign.count
    return nil if f.zero?
    share = pct(f, n)
    top = foreign.group(:country).order('count_all DESC').limit(3).count.map { |c, k| "#{c} #{fmt(k)}" }.join(', ')
    Finding.new(level: share > 40 ? 'warn' : 'info', title: 'Trafic din afara zonei relevante',
                text: "#{share}% din vizitele cu țară cunoscută vin din afara României și a vecinilor (#{top}).",
                hint: share > 40 ? 'Pentru o clinică din Bacău, atât trafic străin înseamnă de obicei centre de date și boți neidentificați. Activează „Doar România + Vecini” când citești cifrele.' : nil)
  end

  def geocoding_coverage
    return nil if total_visits.zero?
    with_country = @visits.where.not(country: [nil, '']).count
    share = pct(with_country, total_visits)
    Finding.new(level: share < 80 ? 'warn' : 'ok', title: 'Acoperire geolocalizare',
                text: "#{share}% din vizite au țara identificată.",
                hint: share < 80 ? 'Geocodarea eșuează des; verifică configurarea gem-ului geocoder și limitele serviciului de IP.' : nil)
  end

  def concentrated_traffic
    return nil if total_visits.zero?
    ip, n = @visits.where.not(ip: [nil, '']).group(:ip).order('count_all DESC').limit(1).count.first
    return nil unless ip
    threshold = [50, total_visits * 0.05].max
    return nil if n < threshold
    Finding.new(level: 'warn', title: 'Trafic concentrat pe un singur IP',
                text: "Un singur IP a generat #{fmt(n)} vizite (#{pct(n, total_visits)}% din total).",
                hint: 'Dacă este IP-ul clinicii sau al unui angajat, exclude-l din statistici; dacă nu, este probabil un scraper.')
  end

  def self_referrals
    return nil if total_visits.zero?
    n = @visits.where('referring_domain ~* ?', SELF_REFERRER).count
    return nil if n.zero?
    share = pct(n, total_visits)
    Finding.new(level: share > 10 ? 'warn' : 'info', title: 'Vizite cu sursa „propriul site”',
                text: "#{fmt(n)} vizite (#{share}%) au ca referrer spinalcare.ro sau serverul vechi (77.81.2.98).",
                hint: 'Sunt sesiuni noi create la întoarcerea de pe site-ul de programări sau prin redirect-ul de pe spinalcare.ro fără www; sursa reală (Google, Facebook) se pierde pentru ele.')
  end

  def uncategorised_clicks
    n = clicks.where("properties->>'category' IS NULL").count
    return nil if n.zero?
    Finding.new(level: 'warn', title: 'Click-uri fără categorie',
                text: "#{fmt(n)} click-uri din perioadă nu au categorie și nu apar în conversii.",
                hint: 'Provin dintr-o versiune veche a tracker-ului; rulează din nou migrarea CleanUpClickEvents.')
  end

  # ---------------------------------------------------------------- insights

  def traffic_trend
    change = change_pct(total_visits, prev_total)
    daily = (total_visits.to_f / days_in_period).round
    text = "#{fmt(total_visits)} vizite de la #{fmt(unique_visitors)} vizitatori unici, în medie #{fmt(daily)} pe zi. "
    text += if prev_total.zero?
              'Nu există perioadă anterioară de comparat.'
            else
              "#{arrow(change)} #{change.abs}% față de perioada anterioară (#{fmt(prev_total)} vizite)."
            end
    Finding.new(level: change < -20 ? 'warn' : 'info', title: 'Trafic', text: text,
                hint: change < -20 ? 'Scădere de peste 20%: verifică în Search Console dacă au scăzut afișările sau dacă o campanie s-a oprit.' : nil)
  end

  def conversion_rate
    by_cat = conversions_by_category
    total = by_cat.values.sum
    rate = per_100(total, unique_visitors)
    prev_rate = per_100(prev_conversions.count, prev_unique)
    calls = by_cat['call'] || 0
    bookings = by_cat['booking'] || 0
    text = "#{fmt(total)} acțiuni de contact: #{fmt(calls)} apeluri și #{fmt(bookings)} deschideri ale programării, adică #{rate} la 100 de vizitatori unici"
    text += prev_unique.positive? ? " (perioada anterioară: #{prev_rate})." : '.'
    level = if prev_unique.positive? && prev_rate.positive? && rate < prev_rate * 0.8 then 'warn'
            elsif prev_unique.positive? && rate > prev_rate then 'ok'
            else 'info'
            end
    hint = if total.zero? then 'Nicio acțiune de contact înregistrată; verifică butoanele de programare și link-urile tel:.'
           elsif calls > bookings * 3 then 'Vizitatorii preferă telefonul; asigură-te că numărul este vizibil pe mobil și că apelurile sunt preluate.'
           elsif bookings > calls * 3 then 'Programarea online domină; verifică periodic că site-ul de programări funcționează.'
           end
    Finding.new(level: level, title: 'Rata de conversie', text: text, hint: hint)
  end

  def converting_pages
    rates = page_conversion_rates.select { |r| r[:conversions].positive? }.sort_by { |r| -r[:rate] }.first(3)
    return nil if rates.empty?
    list = rates.map { |r| "#{r[:page]} (#{r[:rate]}% din #{fmt(r[:views])} vizualizări)" }.join(', ')
    Finding.new(level: 'ok', title: 'Paginile care duc cel mai des la contact', text: "#{list}.",
                hint: 'Acestea merită conținut și promovare; paginile similare pot copia structura lor.')
  end

  def dead_end_pages
    dead = page_conversion_rates.select { |r| r[:conversions].zero? }.sort_by { |r| -r[:views] }.first(3)
    return nil if dead.empty?
    list = dead.map { |r| "#{r[:page]} (#{fmt(r[:views])} vizualizări)" }.join(', ')
    Finding.new(level: 'warn', title: 'Pagini vizitate des, fără nicio acțiune de contact', text: "#{list}.",
                hint: 'Adaugă un buton de programare sau numărul de telefon în partea vizibilă a paginii.')
  end

  def sources
    buckets = bucketize(@visits.group(:referring_domain).count)
    return nil if buckets.empty?
    prev_buckets = bucketize(@prev_visits.group(:referring_domain).count)
    conv_buckets = bucketize(conversion_clicks.joins('INNER JOIN ahoy_visits ON ahoy_visits.id = ahoy_events.visit_id')
                                        .group('ahoy_visits.referring_domain').count)
    shares = buckets.sort_by { |_, n| -n }.first(4).map { |name, n| "#{name} #{pct(n, total_visits)}%" }.join(', ')
    text = "#{shares}. "
    rates = buckets.select { |_, n| n >= 20 }.map { |name, n| [name, per_100(conv_buckets[name] || 0, n)] }
    if rates.size >= 2
      best = rates.max_by(&:last)
      worst = rates.min_by(&:last)
      text += "Cel mai bine convertesc vizitatorii din #{best[0]} (#{best[1]} la 100 de vizite), cel mai slab cei din #{worst[0]} (#{worst[1]}). "
    end
    mover = buckets.map { |name, n| [name, n - (prev_buckets[name] || 0)] }.max_by { |_, d| d.abs }
    if mover && prev_total.positive? && mover[1].abs >= [10, total_visits * 0.05].max
      text += "Cea mai mare schimbare: #{mover[0]} #{arrow(mover[1])} #{fmt(mover[1].abs)} vizite față de perioada anterioară."
    end
    Finding.new(level: 'info', title: 'Surse de trafic', text: text.strip)
  end

  def devices
    by_device = @visits.group(:device_type).count
    mobile = by_device.select { |d, _| d.to_s.match?(/mobile|phablet/i) }.values.sum
    desktop = by_device['Desktop'] || 0
    known = mobile + desktop + (by_device['Tablet'] || 0)
    return nil if known.zero?
    conv = conversion_clicks.joins('INNER JOIN ahoy_visits ON ahoy_visits.id = ahoy_events.visit_id').group('ahoy_visits.device_type').count
    conv_mobile = conv.select { |d, _| d.to_s.match?(/mobile|phablet/i) }.values.sum
    conv_desktop = conv['Desktop'] || 0
    text = "#{pct(mobile, known)}% din vizite vin de pe mobil, #{pct(desktop, known)}% de pe desktop."
    if mobile >= 20 && desktop >= 20
      rm = per_100(conv_mobile, mobile)
      rd = per_100(conv_desktop, desktop)
      text += " Conversie: #{rm} la 100 de vizite pe mobil, #{rd} pe desktop."
      hint = rm < rd * 0.6 ? 'Mobilul convertește mult mai slab: verifică butonul de programare și numărul de telefon pe ecran mic.' : nil
    end
    Finding.new(level: hint ? 'warn' : 'info', title: 'Dispozitive', text: text, hint: hint)
  end

  def geography
    with_city = @visits.where.not(city: [nil, ''])
    n = with_city.count
    return nil if n.zero?
    top = with_city.group(:city).order('count_all DESC').limit(3).count
    bacau = with_city.where('city ILIKE ?', 'bac%u').count
    list = top.map { |c, k| "#{c} #{pct(k, n)}%" }.join(', ')
    Finding.new(level: 'info', title: 'Geografie',
                text: "Bacău reprezintă #{pct(bacau, n)}% din vizitele cu oraș cunoscut. Top orașe: #{list}.")
  end

  def anomalies
    return nil if days_in_period < 7
    daily = @visits.group(Arel.sql('DATE(started_at)')).count
    counts = (0...days_in_period).map { |i| daily[@start_date.to_date + i] || 0 }
    mean = counts.sum.to_f / counts.size
    sd = Math.sqrt(counts.sum { |c| (c - mean)**2 } / counts.size)
    return nil if mean.zero?
    spikes = []
    drops = []
    counts.each_with_index do |c, i|
      date = (@start_date.to_date + i).strftime('%d %b')
      spikes << "#{date} (#{fmt(c)})" if sd.positive? && c > mean + 2 * sd
      drops << "#{date} (#{fmt(c)})" if sd.positive? && c < mean - 2 * sd
    end
    best_i = counts.each_with_index.max_by(&:first).last
    text = "Cea mai bună zi: #{(@start_date.to_date + best_i).strftime('%d %b')} cu #{fmt(counts[best_i])} vizite (media #{fmt(mean.round)}). "
    text += "Vârfuri neobișnuite: #{spikes.join(', ')}. " if spikes.any?
    text += "Căderi neobișnuite: #{drops.join(', ')}." if drops.any?
    Finding.new(level: drops.any? ? 'warn' : 'info', title: 'Zile atipice', text: text.strip,
                hint: (spikes.any? || drops.any?) ? 'Un vârf izolat este de obicei o campanie sau un bot; o cădere izolată, o problemă a site-ului.' : nil)
  end

  def timing
    scope = conversion_clicks.count >= 20 ? conversion_clicks : views
    subject = conversion_clicks.count >= 20 ? 'Apelurile și programările' : 'Vizitele'
    return nil if scope.count.zero?
    tz = Time.zone.tzinfo.name
    local = "((time AT TIME ZONE 'UTC') AT TIME ZONE '#{tz}')"
    by_dow = scope.group(Arel.sql("EXTRACT(DOW FROM #{local})::integer")).count
    by_hour = scope.group(Arel.sql("EXTRACT(HOUR FROM #{local})::integer")).count
    dow = by_dow.max_by { |_, n| n }.first
    hour = by_hour.max_by { |_, n| n }.first
    Finding.new(level: 'info', title: 'Când contactează pacienții',
                text: "#{subject} se concentrează #{WEEKDAYS[dow]} (#{pct(by_dow[dow], scope.count)}% din săptămână), cu vârful între #{hour}:00 și #{hour + 1}:00.",
                hint: conversion_clicks.count >= 20 ? 'Asigură personal la telefon în intervalul de vârf.' : nil)
  end

  # ---------------------------------------------------------------- helpers

  def conversions_by_category
    @conversions_by_category ||= conversion_clicks.group(Arel.sql("properties->>'category'")).count
  end

  def page_conversion_rates
    @page_conversion_rates ||= begin
      views_by_page = views.group(Arel.sql("properties->>'url'")).count
                           .each_with_object(Hash.new(0)) { |(url, n), h| h[path_of(url)] += n }
      conv_by_page = conversion_clicks.group(Arel.sql("properties->>'page'")).count
                                .each_with_object(Hash.new(0)) { |(page, n), h| h[path_of(page)] += n }
      views_by_page.select { |_, n| n >= MIN_PAGE_VIEWS }.map do |page, n|
        c = conv_by_page[page]
        { page: page, views: n, conversions: c, rate: pct(c, n) }
      end
    end
  end

  def bucketize(counts_by_domain)
    counts_by_domain.each_with_object(Hash.new(0)) do |(domain, n), h|
      name = if domain.blank? then 'Direct'
             else SOURCE_BUCKETS.find { |_, re| domain.match?(re) }&.first || 'Altele'
             end
      h[name] += n
    end
  end

  def path_of(url)
    path = url.to_s.sub(%r{\Ahttps?://[^/]+}, '').sub(/[?#].*\z/, '')
    path.blank? || path == '/' ? 'Homepage' : path
  end

  def pct(a, b)
    b.positive? ? (a * 100.0 / b).round(1) : 0.0
  end

  def per_100(a, b)
    pct(a, b)
  end

  def change_pct(now, prev)
    prev.positive? ? (((now - prev).to_f / prev) * 100).round(1) : 0.0
  end

  def arrow(change)
    change >= 0 ? '↑' : '↓'
  end

  def fmt(n)
    ActiveSupport::NumberHelper.number_to_delimited(n)
  end
end
