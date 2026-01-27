Geocoder.configure(
  # Geocoding options
  timeout: 3,                 # geocoding service timeout (secs)
  lookup: :ipinfo_io,         # name of geocoding service (symbol)
  ip_lookup: :ipinfo_io,      # name of IP address geocoding service (symbol)
  language: :ro,              # ISO-639 language code
  use_https: true,            # use HTTPS for lookup requests? (if supported)
  cache: Rails.cache,         # cache object (must respond to #[], #[]=, and #del)
  
  # IPInfo.io is free up to 50,000 requests/month
  # For production, consider getting an API token from https://ipinfo.io
  # Add IPINFO_TOKEN to your environment variables
  # ipinfo_io: {
  #   api_key: ENV['IPINFO_TOKEN']
  # }
)
