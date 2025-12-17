defmodule AshReportsDemo.Application do
  @moduledoc """
  OTP Application for AshReports Demo.

  Manages the lifecycle of the demo application including data generation services,
  session tracking, telemetry collection, and report processing capabilities.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {AshReportsDemo.DataGenerator, []},
        {AshReportsDemoWeb.PdfStore, []},
        {AshReportsDemo.SessionTracker, []},
        {AshReportsDemoWeb.TelemetryCollector, []},
        {Phoenix.PubSub, name: AshReportsDemo.PubSub},
        # Start DNS cluster for Fly.io if configured
        {DNSCluster, query: Application.get_env(:ash_reports_demo, :dns_cluster_query) || :ignore},
        AshReportsDemoWeb.Endpoint
      ]

    opts = [strategy: :one_for_one, name: AshReportsDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
