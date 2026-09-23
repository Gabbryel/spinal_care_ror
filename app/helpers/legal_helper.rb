# The app has no Romanian locale file, so dates in the legal pages are spelled
# out here rather than through I18n (which would print them in English).
module LegalHelper
  MONTHS_RO = %w[ianuarie februarie martie aprilie mai iunie iulie august
                 septembrie octombrie noiembrie decembrie].freeze

  def date_in_romanian(date)
    "#{date.day} #{MONTHS_RO[date.month - 1]} #{date.year}"
  end
end
