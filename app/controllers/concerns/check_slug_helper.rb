module CheckSlugHelper
  def check_slug
    if self[:name]
      self[:slug] == "#{self[:name]}".parameterize ||
      self[:slug] == "#{self[:name]}-#{self[:id]}".parameterize
    elsif self[:first_name] && self[:last_name]
      self[:slug] == "#{self[:first_name]}-#{self[:last_name]}".parameterize ||
      self[:slug] == "#{self[:first_name]}-#{self[:last_name]}-#{self[:id]}".parameterize
    end
  end
end