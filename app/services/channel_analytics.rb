# Paid vs organic: the visits of one period split by traffic channel
# (AnalyticsFilterHelper.channel_sql), each with its own contact numbers,
# plus Google Ads campaigns (gad_campaignid in the landing URL), the ad spend
# typed in by an admin and the resulting cost per contact.
class ChannelAnalytics
  CONVERSION = %w[call booking].freeze
  GROUPS = {
    'paid' => %w[paid_google paid_other],
    'organic' => %w[organic_search],
    'social' => %w[social],
    'direct' => %w[direct],
    'other' => %w[referral self]
  }.freeze
  GROUP_LABELS = { 'paid' => 'Plătit', 'organic' => 'Organic (căutare)', 'social' => 'Social', 'direct' => 'Direct', 'other' => 'Alte site-uri + propriu' }.freeze

  def initialize(visits:, start_date:, end_date:)
    @visits = visits
    @start_date = start_date
    @end_date = end_date
  end

  def channel_sql(prefix = '')
    AnalyticsFilterHelper.channel_sql(prefix)
  end

  def visit_ids_sql
    @visits.select(:id).to_sql
  end

  def total_visits
    @total_visits ||= @visits.count
  end

  # One row per channel with visits, unique visitors, pages per visit,
  # calls, bookings, contacts per 100 visits, returning share and the median
  # time from first page to first contact.
  def channels
    @channels ||= begin
      visits_by = @visits.group(Arel.sql(channel_sql)).count
      uniques_by = @visits.group(Arel.sql(channel_sql)).distinct.count(:visitor_token)
      views_by = joined_events.where(name: '$view').group(Arel.sql(channel_sql('ahoy_visits.'))).count
      conv_by = joined_events.where(name: '$click').where("properties->>'category' IN (?)", CONVERSION)
                             .group(Arel.sql(channel_sql('ahoy_visits.')), Arel.sql("ahoy_events.properties->>'category'")).count
      conv_visits_by = joined_events.where(name: '$click').where("properties->>'category' IN (?)", CONVERSION)
                                    .group(Arel.sql(channel_sql('ahoy_visits.'))).distinct.count('ahoy_events.visit_id')
      returning_by = select_all(<<~SQL).each_with_object({}) { |r, h| h[r['channel']] = r['returning'].to_i }
        SELECT #{channel_sql('v.')} AS channel,
               COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM ahoy_visits p WHERE p.visitor_token = v.visitor_token AND p.started_at < v.started_at)) AS returning
        FROM ahoy_visits v WHERE v.id IN (#{visit_ids_sql}) GROUP BY 1
      SQL
      decision_by = select_all(<<~SQL).group_by { |r| r['channel'] }.transform_values { |rs| median(rs.map { |r| r['seconds'].to_i }) }
        WITH conv AS (
          SELECT visit_id, MIN(time) AS t FROM ahoy_events
          WHERE name = '$click' AND properties->>'category' IN ('call','booking') AND visit_id IN (#{visit_ids_sql}) GROUP BY visit_id
        )
        SELECT #{channel_sql('v.')} AS channel, EXTRACT(EPOCH FROM (conv.t - MIN(e.time)))::int AS seconds
        FROM conv JOIN ahoy_visits v ON v.id = conv.visit_id
        JOIN ahoy_events e ON e.visit_id = conv.visit_id AND e.name = '$view' AND e.time <= conv.t
        GROUP BY v.id, conv.t
      SQL

      # Conversion rate = visits with at least one contact per 100 visits (a
      # visit that clicks the phone three times is one converting visit).
      visits_by.sort_by { |channel, n| [-n, channel] }.map do |channel, n|
        calls = conv_by[[channel, 'call']] || 0
        bookings = conv_by[[channel, 'booking']] || 0
        converting = conv_visits_by[channel] || 0
        {
          channel: channel, visits: n, share: pct(n, total_visits), unique: uniques_by[channel] || 0,
          views_per_visit: (views_by[channel] || 0).fdiv(n).round(1),
          calls: calls, bookings: bookings, contacts: calls + bookings, per_100: pct(converting, n),
          converting_visits: converting,
          returning_share: pct(returning_by[channel] || 0, n),
          median_seconds: decision_by[channel]
        }
      end
    end
  end

  # Paid / organic / social / direct / other, summed from `channels`.
  def groups
    GROUPS.map do |key, members|
      rows = channels.select { |c| members.include?(c[:channel]) }
      visits = rows.sum { |c| c[:visits] }
      contacts = rows.sum { |c| c[:contacts] }
      converting = rows.sum { |c| c[:converting_visits] }
      { group: key, label: GROUP_LABELS[key], visits: visits, share: pct(visits, total_visits),
        calls: rows.sum { |c| c[:calls] }, bookings: rows.sum { |c| c[:bookings] }, contacts: contacts,
        converting_visits: converting, per_100: pct(converting, visits) }
    end.reject { |g| g[:visits].zero? }
  end

  # Google Ads campaigns seen in landing URLs (gad_campaignid), with the name
  # an admin gave them.
  def campaigns
    rows = select_all(<<~SQL)
      SELECT substring(v.landing_page from '[?&]gad_campaignid=([0-9]+)') AS campaign_id,
             COUNT(*) AS visits,
             COUNT(*) FILTER (WHERE EXISTS (
               SELECT 1 FROM ahoy_events e WHERE e.visit_id = v.id AND e.name = '$click' AND e.properties->>'category' IN ('call','booking'))) AS converting,
             MIN(v.started_at)::date AS first_seen, MAX(v.started_at)::date AS last_seen
      FROM ahoy_visits v
      WHERE v.id IN (#{visit_ids_sql}) AND v.landing_page ~* '[?&](gclid|gbraid|wbraid)='
      GROUP BY 1 ORDER BY 2 DESC LIMIT 15
    SQL
    names = AdCampaignName.where(campaign_id: rows.map { |r| r['campaign_id'] }.compact).index_by(&:campaign_id)
    rows.map do |r|
      id = r['campaign_id']
      { campaign_id: id, name: id && names[id]&.name, visits: r['visits'].to_i, converting: r['converting'].to_i,
        per_100: pct(r['converting'].to_i, r['visits'].to_i), first_seen: r['first_seen'], last_seen: r['last_seen'] }
    end
  end

  # Spend typed in for the months touched by the period, and cost per paid
  # contact / per paid visit (approximate when the period cuts a month).
  def spend
    months = (@start_date.to_date.beginning_of_month..@end_date.to_date).select { |d| d.day == 1 }
    rows = AdSpend.where(month: months).order(:month)
    total = rows.sum(&:amount)
    paid = groups.find { |g| g[:group] == 'paid' }
    contacts = paid ? paid[:contacts] : 0
    visits = paid ? paid[:visits] : 0
    { rows: rows, months: months, total: total,
      per_contact: contacts.positive? && total.positive? ? (total / contacts).round(0) : nil,
      per_visit: visits.positive? && total.positive? ? (total / visits).round(2) : nil,
      partial: @start_date.to_date.day != 1 || @end_date.to_date != @end_date.to_date.end_of_month }
  end

  # Visits and contacts per month and channel group, when the period spans
  # more than one month.
  def monthly
    months = (@start_date.to_date.beginning_of_month..@end_date.to_date).select { |d| d.day == 1 }
    return [] if months.size < 2
    visits_by = select_all(<<~SQL)
      SELECT date_trunc('month', v.started_at)::date AS month, #{channel_sql('v.')} AS channel, COUNT(*) AS n,
             COUNT(*) FILTER (WHERE EXISTS (
               SELECT 1 FROM ahoy_events e WHERE e.visit_id = v.id AND e.name = '$click' AND e.properties->>'category' IN ('call','booking'))) AS converting
      FROM ahoy_visits v WHERE v.id IN (#{visit_ids_sql}) GROUP BY 1, 2
    SQL
    group_of = GROUPS.each_with_object({}) { |(g, members), h| members.each { |m| h[m] = g } }
    months.map do |m|
      rows = visits_by.select { |r| Date.parse(r['month'].to_s) == m }
      per_group = GROUPS.keys.each_with_object({}) do |g, h|
        rs = rows.select { |r| group_of[r['channel']] == g }
        h[g] = { visits: rs.sum { |r| r['n'].to_i }, converting: rs.sum { |r| r['converting'].to_i } }
      end
      { month: m, groups: per_group }
    end
  end

  private

  def joined_events
    Ahoy::Event.joins('INNER JOIN ahoy_visits ON ahoy_visits.id = ahoy_events.visit_id').where("ahoy_events.visit_id IN (#{visit_ids_sql})")
  end

  def select_all(sql)
    Ahoy::Event.connection.select_all(sql).to_a
  end

  def pct(a, b)
    b.to_i.positive? ? (a.to_f * 100 / b).round(1) : 0.0
  end

  def median(values)
    return nil if values.empty?
    sorted = values.sort
    sorted[(sorted.size - 1) / 2]
  end
end
