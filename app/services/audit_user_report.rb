# One user's activity in the audit log, for the admin "Jurnal de activitate"
# page: a summary and a day-by-day list of what they did, in plain Romanian.
# Page views are folded into one line per day so edits stay visible.
class AuditUserReport
  TYPE_LABELS = {
    'Member' => 'membrul echipei',
    'MedicalService' => 'serviciul medical',
    'User' => 'utilizatorul',
    'JobPosting' => 'anunțul de carieră',
    'Fact' => 'informația pentru pacient',
    'PromoPackage' => 'pachetul promoțional',
    'MedicinesConsumption' => 'consumul de medicamente',
    'Specialty' => 'specialitatea',
    'Profession' => 'profesia',
    'Review' => 'recenzia'
  }.freeze

  TYPE_PLURALS = {
    'Member' => 'Echipă',
    'MedicalService' => 'Servicii medicale',
    'User' => 'Utilizatori',
    'JobPosting' => 'Cariere',
    'Fact' => 'Info pacient',
    'PromoPackage' => 'Pachete promoționale',
    'MedicinesConsumption' => 'Consum medicamente',
    'Specialty' => 'Specialități',
    'Profession' => 'Profesii',
    'Review' => 'Recenzii'
  }.freeze

  FIELD_LABELS = {
    'price' => 'preț', 'name' => 'nume', 'description' => 'descriere', 'first_name' => 'prenume',
    'last_name' => 'nume de familie', 'selected' => 'selectat', 'order' => 'ordine', 'is_active' => 'activ',
    'has_own_page' => 'pagină proprie', 'email' => 'email', 'admin' => 'admin', 'god_mode' => 'god mode',
    'seo_title' => 'titlu SEO', 'slug' => 'slug', 'title' => 'titlu', 'active' => 'activ',
    'specialty_id' => 'specialitate', 'profession_id' => 'profesie', 'member_id' => 'membru',
    'academic_title' => 'titlu academic', 'doctor_grade' => 'grad', 'sub_name' => 'subtitlu',
    'has_day_hospitalization' => 'spitalizare de zi', 'founder' => 'fondator',
    'specialty_favored' => 'favorit în specialitate', 'is_day_hospitalize' => 'spitalizare de zi',
    'quantity' => 'cantitate', 'date' => 'dată', 'valid_until' => 'valabil până la', 'benefits' => 'beneficii'
  }.freeze

  IGNORED_FIELDS = %w[id created_at updated_at encrypted_password reset_password_token
                      reset_password_sent_at remember_created_at].freeze

  WEEKDAYS = %w[Duminică Luni Marți Miercuri Joi Vineri Sâmbătă].freeze
  MONTHS = %w[ianuarie februarie martie aprilie mai iunie iulie august septembrie octombrie noiembrie decembrie].freeze

  Entry = Struct.new(:time, :kind, :text, :details, :meta, :user, keyword_init: true)
  View = Struct.new(:time, :path, :duration_ms, :status_code, :user, keyword_init: true)
  Day = Struct.new(:date, :label, :entries, :views, keyword_init: true)

  attr_reader :user

  # logs: this user's AuditLog rows for the period, newest first.
  def initialize(user, logs)
    @user = user
    @logs = logs.to_a
  end

  def summary
    @summary ||= begin
      by_action = @logs.group_by(&:action).transform_values(&:size)
      changes = @logs.reject { |l| l.action.in?(%w[view login logout]) }
      {
        creates: by_action['create'] || 0,
        updates: by_action['update'] || 0,
        destroys: by_action['destroy'] || 0,
        changes: changes.size,
        logins: by_action['login'] || 0,
        views: by_action['view'] || 0,
        days_active: @logs.map { |l| l.created_at.to_date }.uniq.size,
        last_at: @logs.first&.created_at,
        errors: @logs.count { |l| l.status_code.to_i >= 400 },
        by_type: changes.group_by(&:auditable_type).map { |type, rows| [TYPE_PLURALS[type] || type, rows.size] }.sort_by { |_, n| -n }
      }
    end
  end

  def days
    @days ||= @logs.group_by { |l| l.created_at.to_date }.map do |date, rows|
      Day.new(
        date: date,
        label: day_label(date),
        entries: rows.reject { |l| l.action == 'view' }.map { |l| entry(l) },
        views: rows.select { |l| l.action == 'view' }.map { |l| View.new(time: l.created_at, path: l.request_path, duration_ms: l.duration_ms, status_code: l.status_code, user: l.user) }
      )
    end
  end

  def self.day_label(date)
    "#{WEEKDAYS[date.wday]}, #{date.day} #{MONTHS[date.month - 1]} #{date.year}"
  end

  # One log row as a sentence, for callers outside a per-user report.
  def self.entry_for(log)
    new(log.user, []).entry(log)
  end

  def entry(log)
    entry = build_entry(log)
    entry.user = log.user
    entry
  end

  private

  def day_label(date)
    self.class.day_label(date)
  end

  def build_entry(log)
    case log.action
    when 'create'
      Entry.new(time: log.created_at, kind: 'create', text: "a creat #{label(log)} #{quoted(name_of(log))}",
                details: [], meta: meta(log))
    when 'update'
      details = change_details(log)
      Entry.new(time: log.created_at, kind: 'update', text: "a modificat #{label(log)} #{quoted(name_of(log))}",
                details: details.presence || [log.changes_summary.presence].compact, meta: meta(log))
    when 'destroy'
      Entry.new(time: log.created_at, kind: 'destroy', text: "a șters #{label(log)} #{quoted(name_of(log))}",
                details: [], meta: meta(log))
    when 'login'
      Entry.new(time: log.created_at, kind: 'login', text: 's-a autentificat', details: [], meta: meta(log, device: true))
    when 'logout'
      Entry.new(time: log.created_at, kind: 'logout', text: 's-a deconectat', details: [], meta: meta(log, device: true))
    when 'view'
      Entry.new(time: log.created_at, kind: 'view', text: "a vizualizat #{log.request_path.presence || label(log)}", details: [], meta: meta(log))
    else
      Entry.new(time: log.created_at, kind: log.action, text: log.full_description, details: [], meta: meta(log))
    end
  end

  def label(log)
    TYPE_LABELS[log.auditable_type] || log.auditable_type.to_s.underscore.humanize.downcase
  end

  # The record's name, from the record itself when it still exists, else from
  # the data captured at the time.
  def name_of(log)
    record = log.auditable rescue nil
    if record
      name = log.auditable_name
      return name unless name.to_s.start_with?('#')
    end
    data = log.parsed_changes
    value = ->(key) { v = data[key]; v.is_a?(Array) ? v.last : v }
    if value.call('first_name').present? || value.call('last_name').present?
      return [value.call('first_name'), value.call('last_name')].compact.join(' ').strip
    end
    %w[name title email].each do |key|
      v = value.call(key)
      return v.to_s if v.present?
    end
    return log.changes_summary if log.action == 'destroy' && log.changes_summary.present?
    "##{log.auditable_id}"
  end

  def quoted(name)
    name.to_s.start_with?('#') ? name : "„#{name.to_s.truncate(60)}”"
  end

  def change_details(log)
    log.parsed_changes.reject { |field, _| IGNORED_FIELDS.include?(field) }.map do |field, value|
      field_label = FIELD_LABELS[field] || field.humanize.downcase
      if value.is_a?(Array) && value.size == 2
        "#{field_label}: #{show(value[0])} → #{show(value[1])}"
      else
        "#{field_label}: #{show(value)}"
      end
    end
  end

  def show(value)
    case value
    when nil, '' then 'gol'
    when true then 'da'
    when false then 'nu'
    else value.to_s.gsub(/<[^>]+>/, ' ').squish.truncate(60)
    end
  end

  def meta(log, device: false)
    parts = []
    parts << "#{log.browser_info} / #{log.device_info}" if device && log.browser_info != 'Unknown'
    parts << "IP #{log.ip_address}" if device && log.ip_address.present?
    parts << "#{log.duration_ms} ms" if log.duration_ms.present?
    parts << "eroare #{log.status_code}" if log.status_code.to_i >= 400
    parts.join(' · ')
  end
end
