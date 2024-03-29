# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://www.spinalcare.ro"
SitemapGenerator::Sitemap.compress = false

SitemapGenerator::Sitemap.create do
  add "/",
  changefreq: 'weekly',
  priority: 0.4

  add "/echipa",
  changefreq: 'daily',
  priority: 0.6

  add "/servicii-medicale",
  changefreq: 'daily',
  priority: 0.6

  Member.all.order(id: :desc).each do |m|
    add "/echipa/#{m.slug}",
    changefreq: 'daily',
    lastmod: m.updated_at,
    priority: 0.6
  end

  Specialty.all.order(id: :desc).each do |s|
    add "/specialitati-medicale/#{s.slug}",
    changefreq: 'daily',
    lastmod: s.updated_at,
    priority: 0.4
  end
  # Put links creation logic here.
  #
  # The root path '/' and sitemap index file are added automatically for you.
  # Links are added to the Sitemap in the order they are specified.
  #
  # Usage: add(path, options={})
  #        (default options are used if you don't specify)
  #
  # Defaults: :priority => 0.5, :changefreq => 'weekly',
  #           :lastmod => Time.now, :host => default_host
  #
  # Examples:
  #
  # Add '/articles'
  #
  #   add articles_path, :priority => 0.7, :changefreq => 'daily'
  #
  # Add all articles:
  #
  #   Article.find_each do |article|
  #     add article_path(article), :lastmod => article.updated_at
  #   end
end
