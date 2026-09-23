# Operator details rendered in the privacy and cookie policy (config/legal.yml).
LEGAL = YAML.load_file(Rails.root.join("config/legal.yml")).freeze
