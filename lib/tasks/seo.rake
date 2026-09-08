namespace :seo do
  desc "Regenerate slugs corrupted by Romanian diacritics (ș/ț were dropped), keeping 301 redirects. DRY_RUN=1 to preview."
  task fix_slugs: :environment do
    dry_run = ENV["DRY_RUN"].present?
    changed = 0

    [Specialty, Member, Fact, Profession, MedicalService].each do |klass|
      klass.find_each do |record|
        next if record.check_slug

        old_slug = record.slug
        if dry_run
          puts "#{klass.name}##{record.id}: #{old_slug} (would regenerate)"
        else
          record.slugify
          puts "#{klass.name}##{record.id}: #{old_slug} -> #{record.slug}"
        end
        changed += 1
      end
    end

    puts "#{changed} slug(s) #{dry_run ? 'would be' : ''} regenerated; redirects stored in slug_redirects."
  end
end

namespace :seo do
  desc "Retire the empty 'Fiziokinetoterapie' specialty (301 -> Fizioterapie și Recuperare medicală) and attach unassigned physiotherapists to it. Idempotent."
  task restructure_recovery: :environment do
    target = Specialty.find_by!(slug: "fizioterapie-si-recuperare-medicala")
    retired = Specialty.find_by(slug: "fiziokinetoterapie")

    if retired
      if retired.members.any? || retired.medical_services.any?
        abort "fiziokinetoterapie still has #{retired.members.count} member(s) / #{retired.medical_services.count} service(s); move them first."
      end
      redirect = SlugRedirect.find_or_initialize_by(sluggable_type: "Specialty", old_slug: retired.slug)
      redirect.update!(new_slug: target.slug, sluggable_id: target.id)
      retired.destroy!
      puts "Specialty 'fiziokinetoterapie' removed; 301 -> /specialitati-medicale/#{target.slug}"
    else
      puts "Specialty 'fiziokinetoterapie' already gone."
    end

    unassigned = Member.joins(:profession)
                       .where(professions: { slug: %w[fiziokinetoterapeut asistent-medical-bfkt] }, specialty_id: nil, is_active: true)
    names = unassigned.map(&:name)
    moved = unassigned.update_all(specialty_id: target.id, updated_at: Time.current)
    puts "#{moved} team member(s) attached to '#{target.name}': #{names.join(', ')}"
  end
end
