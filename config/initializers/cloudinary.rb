# Cloudinary configuration for view helpers (cl_image_tag) and direct uploads.
# Active Storage uses config/storage.yml for its service configuration.

Cloudinary.config do |config|
  config.cloud_name = ENV["CLOUDINARY_CLOUD_NAME"]
  config.api_key = ENV["CLOUDINARY_API_KEY"]
  config.api_secret = ENV["CLOUDINARY_API_SECRET"]
  config.secure = true
end
