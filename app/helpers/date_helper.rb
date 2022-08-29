module DateHelper
  def date_ro(date)
    date.to_s.split(' ').first.split('-').reverse().join('-')
  end
end