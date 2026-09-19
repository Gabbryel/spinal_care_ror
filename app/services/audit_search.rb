# Global search over the audit log, for "who changed X?": every user, all
# time. Each word of the query must match either the stored text (record
# name in the description or captured data, path, IP, changes) or the user's
# email, or name a section ("servicii medicale") or an action ("șters").
# Diacritics are ignored on both sides.
class AuditSearch
  LIMIT = 200
  FOLD_FROM = 'ăâîșțşţ'.freeze
  FOLD_TO = 'aaistst'.freeze
  TEXT_COLUMNS = %w[audit_logs.description audit_logs.changes_summary audit_logs.change_data
                    audit_logs.request_path audit_logs.ip_address users.email].freeze
  ACTION_WORDS = {
    'create' => %w[creat creare creari adaugat],
    'update' => %w[modificat modificare modificari editat editare],
    'destroy' => %w[sters stergere stergeri],
    'login' => %w[autentificat autentificare login logare],
    'logout' => %w[deconectat delogat],
    'view' => %w[vizualizat vizualizare vizitat]
  }.freeze

  Day = Struct.new(:date, :label, :entries, keyword_init: true)

  attr_reader :query

  def initialize(query, limit: LIMIT)
    @query = query.to_s.squish
    @limit = limit
  end

  def tokens
    @tokens ||= self.class.fold(@query).split(' ').reject(&:blank?).uniq
  end

  def logs
    @logs ||= begin
      scope = AuditLog.joins(:user).includes(:user)
      tokens.each { |token| scope = scope.where(token_condition(token)) }
      self.class.preload_auditables(scope.order(created_at: :desc).limit(@limit).to_a)
    end
  end

  def total
    @total ||= begin
      scope = AuditLog.joins(:user)
      tokens.each { |token| scope = scope.where(token_condition(token)) }
      scope.count
    end
  end

  def truncated?
    total > logs.size
  end

  def days
    @days ||= logs.group_by { |l| l.created_at.to_date }.map do |date, rows|
      Day.new(date: date, label: AuditUserReport.day_label(date), entries: rows.map { |l| AuditUserReport.entry_for(l) })
    end
  end

  # Only create/update/destroy rows read their record (for its current
  # name); preloading it on view/login rows would be an unused eager load.
  def self.preload_auditables(logs)
    rows = logs.select { |l| l.action.in?(%w[create update destroy]) }
    ActiveRecord::Associations::Preloader.new(records: rows, associations: :auditable).call if rows.any?
    logs
  end

  def self.fold(text)
    text.to_s.downcase.tr(FOLD_FROM, FOLD_TO)
  end

  private

  def token_condition(token)
    like = "%#{ActiveRecord::Base.sanitize_sql_like(token)}%"
    parts = TEXT_COLUMNS.map do |column|
      AuditLog.sanitize_sql_array(["translate(lower(coalesce(#{column}, '')), ?, ?) LIKE ?", FOLD_FROM, FOLD_TO, like])
    end
    types = types_for(token)
    parts << AuditLog.sanitize_sql_array(['audit_logs.auditable_type IN (?)', types]) if types.any?
    actions = actions_for(token)
    parts << AuditLog.sanitize_sql_array(['audit_logs.action IN (?)', actions]) if actions.any?
    "(#{parts.join(' OR ')})"
  end

  # "servicii", "echipa", "pachet" -> the section's model names.
  def types_for(token)
    return [] if token.size < 4
    AuditUserReport::TYPE_LABELS.merge(AuditUserReport::TYPE_PLURALS) { |_, a, b| "#{a} #{b}" }.select do |_, labels|
      labels.split(' ').any? { |word| self.class.fold(word).start_with?(token) }
    end.keys
  end

  def actions_for(token)
    ACTION_WORDS.select { |_, words| words.any? { |w| w.start_with?(token) && token.size >= 4 } }.keys
  end
end
