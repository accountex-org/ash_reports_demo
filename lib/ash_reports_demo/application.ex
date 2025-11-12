defmodule AshReportsDemo.Application do
  @moduledoc """
  OTP Application for AshReports Demo.

  Manages the lifecycle of the demo application including ETS data layer,
  data generation services, and report processing capabilities.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {AshReportsDemo.EtsDataLayer, []},
      {AshReportsDemo.DataGenerator, []},
      {AshReportsDemoWeb.PdfStore, []},
      {AshReportsDemo.SessionTracker, []},
      {AshReportsDemoWeb.TelemetryCollector, []},
      {Phoenix.PubSub, name: AshReportsDemo.PubSub},
      AshReportsDemoWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: AshReportsDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
