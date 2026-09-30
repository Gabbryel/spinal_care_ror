require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SpinalCareRor
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0
    config.active_storage.variant_processor = :mini_magick
    # A Pundit refusal is a 403, not a 500 (it used to surface as a server error).
    config.action_dispatch.rescue_responses["Pundit::NotAuthorizedError"] = :forbidden

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Europe/Bucharest"
    # config.eager_load_paths << Rails.root.join("extras")


    config.action_mailer.delivery_method     = :postmark
    config.action_mailer.postmark_settings   = { api_token: ENV['POSTMARK_API_TOKEN'] }
    config.action_mailer.default_url_options = { host: "www.spinalcare.ro", protocol: "https" }
  end
end
