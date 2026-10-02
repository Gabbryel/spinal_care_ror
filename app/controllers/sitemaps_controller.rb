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
    add "/politica-de-confidentialitate", lastmod: Date.parse(LEGAL["updated_on"]), changefreq: "yearly", priority: 0.2
    add "/promotii", lastmod: latest(promo_packages), changefreq: "weekly", priority: 0.6 if promo_packages.exists?
    add "/cariere", lastmod: latest(job_postings), changefreq: "weekly", priority: 0.4 if job_postings.exists?

    specialties.each do |specialty|
      add "/specialitati-medicale/#{specialty.slug}", lastmod: specialty.updated_at, changefreq: "monthly", priority: 0.7
    end

    members.each do |member|
      add "/echipa/#{member.slug}", lastmod: member.updated_at, changefreq: "monthly", priority: 0.6
    end

    facts.each do |fact|
      add "/info-pacient/#{fact.slug}", lastmod: fact.updated_at, changefreq: "monthly", priority: 0.4
    end

    add_health_topics

    expires_in 1.hour, public: true
    render formats: :xml
  end

  private

  # Published condition and procedure pages (none until the table exists).
  def add_health_topics
    topics = HealthTopic.published.order(:kind, :name)
    return unless topics.exists?

    add "/afectiuni-si-proceduri", lastmod: latest(topics), changefreq: "weekly", priority: 0.6
    topics.each { |topic| add topic.public_path, lastmod: topic.updated_at, changefreq: "monthly", priority: 0.6 }
  rescue ActiveRecord::StatementInvalid
    nil
  end

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
