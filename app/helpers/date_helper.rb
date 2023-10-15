module DateHelper
  def date_ro(date)
    date.to_s.split(' ').first.split('-').reverse().join('-')
  end
  def date_ro_with_hour(date)
    d = date.to_s.split(' ').slice(0, 2)
    d_1 = d[0].split('-').reverse.join('/')
    d_2 = d[1].split(':').first(2).join(':')
    d_1 + ' ' + d_2
  end
end