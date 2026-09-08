module SlugHelper
  def slugify
    previous_slug = self[:slug].presence

    if self[:name]
      future_slug = "#{self[:name]}".parameterize
    elsif self[:first_name] && self[:last_name]
      future_slug = "#{self[:first_name]}-#{self[:last_name]}".parameterize
    end
    if slug_helper(future_slug)
      self[:slug] = future_slug
      self.save
    else
      if self[:name]
        self[:slug] = "#{self[:name]}-#{self[:id]}".parameterize
        self.save
      elsif
        self[:slug] = "#{future_slug}-#{self[:id]}"
        self.save
      end
    end

    # Keep old, already indexed URLs working with a 301 to the new slug.
    SlugRedirect.record(self, previous_slug) if previous_slug && previous_slug != self[:slug]
  end
end
