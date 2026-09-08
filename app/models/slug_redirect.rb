# Remembers retired slugs so old, already indexed URLs keep working with a
# 301 to the current slug. Written by SlugHelper#slugify whenever a record's
# slug changes; read by SlugRedirectable in the public controllers.
class SlugRedirect < ApplicationRecord
  validates :sluggable_type, :old_slug, :new_slug, presence: true
  validates :old_slug, uniqueness: { scope: :sluggable_type }

  def self.record(record, old_slug)
    new_slug = record.slug
    return if old_slug.blank? || new_slug.blank? || old_slug == new_slug

    type = record.class.name
    transaction do
      # The new slug must never itself be a redirect source (would loop).
      where(sluggable_type: type, old_slug: new_slug).delete_all
      # Collapse chains: anything that pointed at the retired slug now points at the new one.
      where(sluggable_type: type, new_slug: old_slug).update_all(new_slug: new_slug, updated_at: Time.current)

      redirect = find_or_initialize_by(sluggable_type: type, old_slug: old_slug)
      redirect.sluggable_id = record.id
      redirect.new_slug = new_slug
      redirect.save!
    end
  end

  def self.lookup(klass, old_slug)
    find_by(sluggable_type: klass.name, old_slug: old_slug)
  end
end
