defmodule AshReportsDemoWeb.Router do
  use AshReportsDemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AshReportsDemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug AshReportsDemoWeb.SessionTrackingPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AshReportsDemoWeb do
    pipe_through :browser

    live "/", HomeLive

    live "/data-summary", DataSummaryLive

    # Report demonstrations
    live "/reports", ReportLive.Index, :index
    live "/reports/:name", ReportLive.Viewer, :show

    get "/pdf/:id/download", PdfController, :download
    get "/pdf/:id/view", PdfController, :view

    # Dashboard demonstrations
    live "/dashboard", DashboardLive.Index, :index

    # Chart demonstrations
    live "/charts", ChartLive.Index, :index
    live "/charts/:name", ChartLive.Viewer, :show
  end

  # API endpoints
  scope "/api", AshReportsDemoWeb do
    pipe_through :api

    get "/reports", ReportApiController, :index
    get "/reports/:name", ReportApiController, :show
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:ash_reports_demo, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AshReportsDemoWeb.Telemetry
    end
  end
end
