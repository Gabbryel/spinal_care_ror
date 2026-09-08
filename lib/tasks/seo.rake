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
