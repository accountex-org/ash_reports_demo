defmodule AshReportsDemoWeb.HomeLive do
  use AshReportsDemoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />
    <div class="mx-auto max-w-xl">
      <.header class="text-center">
        Welcome to AshReports Demo
        <:subtitle>
          Interactive demonstrations of AshReports capabilities including charts,
          dashboards, and comprehensive reporting features.
        </:subtitle>
      </.header>
    </div>
    """
  end
end
