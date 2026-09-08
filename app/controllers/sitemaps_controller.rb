# Serves /sitemap.xml dynamically so lastmod/changefreq always reflect the
# database. Heroku's filesystem is ephemeral, so a statically generated file
# in public/ could never be kept current there.
class SitemapsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_after_action :log_action_view
  before_action :skip_authorization

  def show
    @entries = []

    specialties = Specialty.where(is_active: true).order(:name)
    members = Member.where(is_active: true, has_own_page: true).order(:last_name)
    facts = Fact.order(:name)
    promo_packages = PromoPackage.active
    job_postings = JobPosting.active

    add "/", lastmod: latest(specialties, members, promo_packages), changefreq: "weekly", priority: 1.0
    add "/specialitati-medicale", lastmod: latest(specialties), changefreq: "monthly", priority: 0.8
    add "/echipa", lastmod: latest(members), changefreq: "monthly", priority: 0.8
    add "/servicii-medicale", lastmod: MedicalService.maximum(:updated_at), changefreq: "monthly", priority: 0.7
    add "/info-pacient-index", lastmod: latest(facts), changefreq: "monthly", priority: 0.5
    add "/promotii", lastmod: latest(promo_packages), changefreq: "weekly", priority: 0.6 if promo_packages.exists?
    add "/cariere", lastmod: latest(job_postings), changefreq: "weekly", priority: 0.4 if job_postings.exists?

    specialties.each do |specialty|
      add "/specialitati-medicale/#{specialty.slug}", lastmod: specialty.updated_at, changefreq: "monthly", priority: 0.7
      if specialty.medical_services_count.to_i.positive?
        add "/servicii-medicale/#{specialty.slug}", lastmod: specialty.updated_at, changefreq: "monthly", priority: 0.6
      end
    end

    members.each do |member|
      add "/echipa/#{member.slug}", lastmod: member.updated_at, changefreq: "monthly", priority: 0.6
    end

    facts.each do |fact|
      add "/info-pacient/#{fact.slug}", lastmod: fact.updated_at, changefreq: "monthly", priority: 0.4
    end

    expires_in 1.hour, public: true
    render formats: :xml
  end

  private

  def add(path, lastmod:, changefreq:, priority:)
    @entries << {
      loc: helpers.canonical_url_for(path),
      lastmod: lastmod,
      changefreq: changefreq,
      priority: priority
    }
  end

  def latest(*relations)
    relations.filter_map { |relation| relation.maximum(:updated_at) }.max
  end
end
