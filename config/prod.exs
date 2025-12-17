import Config

# Production configuration for AshReportsDemo
# Note: runtime configuration is in config/runtime.exs

config :ash_reports_demo, AshReportsDemoWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

# Do not print debug messages in production
config :logger, level: :info

# Disable auto data generation (data loaded from JSON files)
config :ash_reports_demo,
  auto_generate_data: false

# Enable PDF generation
config :ash_reports,
  enable_pdf: true

# Configure data generator for production
config :ash_reports_demo, AshReportsDemo.DataGenerator,
  auto_start: true,
  default_volume: :small,
  regenerate_on_start: false

# Runtime production configuration is in config/runtime.exs
