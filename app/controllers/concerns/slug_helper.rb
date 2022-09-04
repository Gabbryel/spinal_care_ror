module SlugHelper
  def slugify
    if self.name
      future_slug = "#{self.name}".parameterize
    elsif self.first_name && self.last_name
      future_slug = "#{self.first_name}-#{self.last_name}".parameterize
    end
    if slug_helper(future_slug)
      self.slug = future_slug
      self.save
    else
      if self.name
        self.slug = "#{self.name}-#{self.id}".parameterize
        self.save
      elsif
        self.slug = "#{future_slug}-#{self.id}"
        self.save
      end
    end
  end
end