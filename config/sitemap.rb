require 'rubygems'
require 'sitemap_generator'

SitemapGenerator::Sitemap.default_host = 'https://www.spinalcare.ro'
SitemapGenerator.verbose = false
SitemapGenerator::Sitemap.create do
  add '/', :changefreq => 'daily', :priority => 0.9
  add '/echipa', :changefreq => 'weekly'
end
SitemapGenerator::Sitemap.ping_search_engines