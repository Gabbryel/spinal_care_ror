# Display helpers for questionnaire answers in the dashboard. Colour never
# carries the meaning alone: every band also has a symbol and a word.
module SurveysHelper
  BANDS = {
    good: { symbol: "✓", word: "bine" },
    mid: { symbol: "~", word: "mediu" },
    weak: { symbol: "!", word: "slab" },
    neutral: { symbol: "·", word: "fără scor" }
  }.freeze

  # Diverging scale for the distribution bars (validated for colour-vision
  # deficiency): best two in blue, worst two in orange, middle grey, options
  # without a score light grey. Percentages are always written out as well.
  def option_color(score)
    return "#e5e7eb" if score.nil?
    return "#1d4ed8" if score >= 90
    return "#60a5fa" if score >= SurveyInsights::FAVORABLE
    return "#c2410c" if score.zero?
    return "#fb923c" if score <= SurveyInsights::UNFAVORABLE

    "#9ca3af"
  end

  def answer_band(score)
    SurveyResponse.band(score)
  end

  # A chosen answer as a pill: "✓ Foarte bine", coloured by band.
  def answer_pill(label, score, extra_class = nil)
    band = answer_band(score)
    tag.span(class: ["sv-pill", "sv-pill--#{band}", extra_class].compact.join(" "), title: BANDS[band][:word]) do
      safe_join([tag.span(BANDS[band][:symbol], class: "sv-pill-mark", "aria-hidden": "true"), label], " ")
    end
  end

  def score_chip(score)
    return tag.span("–", class: "sv-score sv-score--neutral") if score.nil?

    tag.span("#{score.round}/100", class: "sv-score sv-score--#{answer_band(score)}")
  end

  # "+4,2" / "−3" against the previous period, or nothing without a base.
  def delta_badge(now, before, unit: "")
    return "" if now.nil? || before.nil?

    delta = (now - before).round(1)
    return tag.span("= față de luna anterioară", class: "sv-delta") if delta.zero?

    sign = delta.positive? ? "+" : "−"
    tag.span("#{sign}#{number_with_precision(delta.abs, precision: 1, strip_insignificant_zeros: true)}#{unit} față de luna anterioară",
             class: "sv-delta sv-delta--#{delta.positive? ? 'up' : 'down'}")
  end

  # A 12-point inline SVG line (weekly index); gaps where a week had no answers.
  def sparkline(values, width: 160, height: 36)
    points = values.each_with_index.filter_map do |v, i|
      next if v.nil?

      x = (i * (width - 8) / [values.size - 1, 1].max.to_f + 4).round(1)
      y = (height - 4 - v / 100.0 * (height - 8)).round(1)
      [x, y]
    end
    label = values.compact.any? ? "Indice săptămânal, ultimele 12 săptămâni: #{values.map { |v| v ? v.round : '–' }.join(', ')}" : "Fără răspunsuri în ultimele 12 săptămâni"
    tag.svg(class: "sv-spark", viewBox: "0 0 #{width} #{height}", width: width, height: height, role: "img", "aria-label": label) do
      next "".html_safe if points.empty?

      safe_join([
        tag.polyline(points: points.map { |x, y| "#{x},#{y}" }.join(" "), fill: "none", stroke: "#1d4ed8",
                     "stroke-width": 2, "stroke-linejoin": "round", "stroke-linecap": "round"),
        tag.circle(cx: points.last[0], cy: points.last[1], r: 3.5, fill: "#1d4ed8", stroke: "white", "stroke-width": 1.5)
      ])
    end
  end
end
