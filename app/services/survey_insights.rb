# Reads a survey's responses for a period and says, in Romanian, what the
# patients are telling the clinic: a satisfaction index, the strongest and
# weakest questions, gaps between specialties, the trend against the previous
# period, recurring themes in the comments, and the negative responses still
# waiting for someone to look at them. Rule-based, like AnalyticsInsights.
class SurveyInsights
  Finding = AnalyticsInsights::Finding

  MIN_RESPONSES = 10     # below this, every conclusion carries a warning
  MIN_PER_QUESTION = 5   # a question needs this many answers to be ranked
  MIN_PER_SEGMENT = 5    # a specialty needs this many responses to be compared
  FAVORABLE = 67         # "Bine" or better on the four-point scale
  UNFAVORABLE = 33       # "Satisfăcător" or worse

  # Comment themes: matched without diacritics, on word starts.
  THEMES = {
    "Curățenie" => /\b(curat|curaten|murdar|mizer|praf|igien)/,
    "Mâncare" => /\b(mancare|meniu|masa\b|mesele|hrana|portii)/,
    "Personal medical" => /\b(medic|doctor|asistent|infirmier|personal|cadre)/,
    "Comunicare și informare" => /\b(explic|inform|comunic|raspuns|nu mi s-a spus)/,
    "Timp de așteptare" => /\b(astept|intarzi|coada|programar)/,
    "Cazare și confort" => /\b(camer|salon|pat\b|paturi|zgomot|caldur|frig|aer condit|baie|dus\b|lenjer)/,
    "Medicamente" => /\b(medicament|reteta|pastil|tratament)/,
    "Acces și parcare" => /\b(parcar|acces|lift|scari)/,
    "Mulțumiri" => /\b(multumesc|multumim|minunat|excelent|recomand|profesionis|amabil)/
  }.freeze

  attr_reader :survey, :responses, :previous

  def initialize(survey, responses:, previous:)
    @survey = survey
    @responses = responses.to_a
    @previous = previous.to_a
    @rating_questions = survey.active_questions.select(&:rating?)
  end

  def count
    responses.size
  end

  def satisfaction_index(rows = responses)
    scores = rows.filter_map(&:score)
    scores.any? ? (scores.sum / scores.size).round(1) : nil
  end

  # Share of each headline answer ("Foarte mulțumit", "Mulțumit", "Nemulțumit").
  def headline
    q = survey.headline_question
    return nil unless q

    answers = responses.filter_map { |r| r.answer_for(q)&.dig("label") }
    return nil if answers.empty?

    total = answers.size
    { question: q, total: total, shares: q.labels.map { |l| [l, pct(answers.count(l), total)] } }
  end

  # One row per rating question: answers, mean score, favourable and
  # unfavourable shares, and the count of each option.
  def questions
    @questions ||= @rating_questions.map do |q|
      answers = responses.filter_map { |r| r.answer_for(q) }
      scores = answers.filter_map { |a| a["score"] }
      n = scores.size
      {
        question: q, n: n,
        mean: n.positive? ? (scores.sum.to_f / n).round(1) : nil,
        favorable: pct(scores.count { |s| s >= FAVORABLE }, n),
        unfavorable: pct(scores.count { |s| s <= UNFAVORABLE }, n),
        counts: q.labels.map { |l| [l, answers.count { |a| a["label"] == l }] }
      }
    end
  end

  def ranked
    questions.select { |row| row[:n] >= MIN_PER_QUESTION && row[:mean] }.sort_by { |row| row[:mean] }
  end

  def weakest(limit = 3)
    ranked.first(limit)
  end

  def strongest(limit = 3)
    ranked.last(limit).reverse
  end

  # Distribution of the descriptive questions (age, how they came in, medicines).
  def choices
    survey.active_questions.select { |q| q.kind == "choice" }.map do |q|
      answers = responses.filter_map { |r| r.answer_for(q)&.dig("label") }
      { question: q, n: answers.size, counts: q.labels.map { |l| [l, answers.count(l), pct(answers.count(l), answers.size)] } }
    end
  end

  # Satisfaction per answer of a segment question (specialty, age, sex).
  def segments
    survey.active_questions.select(&:segment).map do |q|
      rows = q.labels.map do |label|
        group = responses.select { |r| r.answer_for(q)&.dig("label") == label }
        { label: label, n: group.size, index: satisfaction_index(group) }
      end
      { question: q, rows: rows }
    end
  end

  # Mean score per month for the period.
  def trend
    responses.group_by { |r| r.created_at.beginning_of_month.to_date }.sort.map do |month, rows|
      { month: month, n: rows.size, index: satisfaction_index(rows) }
    end
  end

  def comments
    responses.select(&:comment).sort_by(&:created_at).reverse
  end

  def themes
    THEMES.map do |name, pattern|
      matching = comments.select { |r| I18n.transliterate(r.comment.downcase).match?(pattern) }
      { theme: name, n: matching.size, negative: matching.count(&:alert) }
    end.select { |t| t[:n].positive? }.sort_by { |t| -t[:n] }
  end

  def open_alerts
    responses.select { |r| r.alert && r.status == "new" }
  end

  def findings
    return [Finding.new(level: "info", title: "Niciun răspuns în perioadă", text: "Nu există răspunsuri la acest chestionar în perioada selectată.")] if count.zero?

    [sample_size, index_finding, trend_finding, weakest_finding, strongest_finding, yes_no_findings,
     segment_finding, themes_finding, alerts_finding].flatten.compact
  end

  private

  def pct(part, total)
    total.positive? ? (part * 100.0 / total).round(1) : 0
  end

  def sample_size
    return if count >= MIN_RESPONSES

    Finding.new(level: "warn", title: "Puține răspunsuri",
                text: "Doar #{count} #{count == 1 ? 'răspuns' : 'răspunsuri'} în perioadă.",
                hint: "Concluziile de mai jos sunt orientative până la cel puțin #{MIN_RESPONSES} răspunsuri. Încurajați pacienții la externare să completeze chestionarul.")
  end

  def index_finding
    index = satisfaction_index
    return unless index

    h = headline
    satisfied = h && h[:shares].select { |l, _| h[:question].score_for(l).to_i >= 50 }.sum { |_, share| share }
    level = index >= 80 ? "ok" : (index >= 60 ? "warn" : "bad")
    text = "Indicele de satisfacție este #{index}/100 (media tuturor răspunsurilor evaluate), din #{count} chestionare."
    text += " #{satisfied.round(1)}% se declară mulțumiți sau foarte mulțumiți în general." if satisfied
    Finding.new(level: level, title: "Satisfacția generală", text: text,
                hint: level == "ok" ? nil : "Sub 80 merită urmărite întrebările cele mai slab evaluate, de mai jos.")
  end

  def trend_finding
    now = satisfaction_index
    before = satisfaction_index(previous)
    return unless now && before && previous.size >= MIN_PER_SEGMENT

    delta = (now - before).round(1)
    return Finding.new(level: "info", title: "Tendință", text: "Indicele e stabil față de perioada anterioară (#{before}/100, #{previous.size} răspunsuri).") if delta.abs < 3

    Finding.new(level: delta.positive? ? "ok" : "warn", title: "Tendință",
                text: "Indicele a #{delta.positive? ? 'crescut' : 'scăzut'} cu #{delta.abs} puncte față de perioada anterioară (#{before}/100, #{previous.size} răspunsuri).")
  end

  def weakest_finding
    row = weakest(1).first
    return unless row && row[:mean] < 80

    Finding.new(level: row[:mean] < 60 ? "bad" : "warn", title: "Cel mai slab evaluat",
                text: "„#{label(row[:question])}”: #{row[:mean]}/100; #{row[:unfavorable]}% din răspunsuri sunt slabe.",
                hint: "Este primul aspect de discutat cu echipa: pacienții îl resimt cel mai mult.")
  end

  def strongest_finding
    row = strongest(1).first
    return unless row && row[:mean] >= 80

    Finding.new(level: "ok", title: "Cel mai bine evaluat",
                text: "„#{label(row[:question])}”: #{row[:mean]}/100; #{row[:favorable]}% din răspunsuri sunt favorabile.")
  end

  # Yes/no questions where a "no" means something was missed (rights,
  # diagnosis, medicines): one finding listing every question at 10% or more.
  def yes_no_findings
    rows = questions.select { |row| row[:question].labels == %w[Da Nu] && row[:n] >= MIN_PER_QUESTION }.filter_map do |row|
      no = row[:counts].to_h["Nu"]
      share = pct(no, row[:n])
      [label(row[:question]), share, no, row[:n]] if share >= 10
    end
    return if rows.empty?

    worst = rows.map { |r| r[1] }.max
    Finding.new(level: worst >= 25 ? "bad" : "warn", title: "Răspunsuri „Nu”",
                text: rows.sort_by { |r| -r[1] }.map { |q, share, no, n| "#{share}% „Nu” la „#{q}” (#{no} din #{n})" }.join("; ") + ".",
                hint: "Un „Nu” aici înseamnă de obicei o informație sau un pas care a lipsit; merită verificat cu echipa de pe secție.")
  end

  def segment_finding
    overall = satisfaction_index
    return unless overall

    gaps = segments.flat_map do |seg|
      seg[:rows].select { |r| r[:n] >= MIN_PER_SEGMENT && r[:index] && overall - r[:index] >= 10 }
                .map { |r| "#{r[:label]} (#{r[:index]}/100, #{r[:n]} răspunsuri)" }
    end
    return if gaps.empty?

    Finding.new(level: "warn", title: "Diferențe între grupuri",
                text: "Sub media clinicii (#{overall}/100) cu cel puțin 10 puncte: #{gaps.join('; ')}.",
                hint: "Comparația ține cont doar de grupurile cu cel puțin #{MIN_PER_SEGMENT} răspunsuri.")
  end

  def themes_finding
    top = themes.reject { |t| t[:theme] == "Mulțumiri" }.first(3)
    thanks = themes.find { |t| t[:theme] == "Mulțumiri" }
    return if top.empty? && thanks.nil?

    parts = top.map { |t| "#{t[:theme].downcase} (#{t[:n]}#{t[:negative].positive? ? ", #{t[:negative]} negative" : ''})" }
    text = parts.any? ? "Comentariile vorbesc cel mai des despre: #{parts.join(', ')}." : ""
    text += " #{thanks[:n]} comentarii conțin mulțumiri sau laude." if thanks
    Finding.new(level: "info", title: "Ce scriu pacienții", text: text.strip,
                hint: "Temele se recunosc după cuvinte-cheie; citiți comentariile pentru context.")
  end

  def alerts_finding
    open = open_alerts.size
    return Finding.new(level: "ok", title: "Răspunsuri negative", text: "Toate răspunsurile negative din perioadă au fost văzute.") if open.zero? && responses.any?(&:alert)
    return if open.zero?

    Finding.new(level: "bad", title: "Răspunsuri negative nevăzute",
                text: "#{open} #{open == 1 ? 'răspuns negativ așteaptă' : 'răspunsuri negative așteaptă'} să fie citite.",
                hint: "Deschideți lista răspunsurilor filtrată pe „negative” și marcați-le ca văzute sau rezolvate.")
  end

  def label(question)
    question.text.delete_suffix(":").delete_suffix("?")
  end
end
