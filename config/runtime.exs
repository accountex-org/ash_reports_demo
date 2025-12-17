import Config

# Runtime configuration for production deployments (Fly.io)
# This file is executed at runtime, not compile time.

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "ash-reports-demo.fly.dev"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :ash_reports_demo, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :ash_reports_demo, AshReportsDemoWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end
