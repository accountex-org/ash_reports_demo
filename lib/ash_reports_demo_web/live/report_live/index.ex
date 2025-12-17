defmodule AshReportsDemoWeb.ReportLive.Index do
  @moduledoc """
  Report listing page that displays all available reports from the domain.

  This LiveView provides:
  - Dynamic report list from AshReports.Info
  - Report metadata display (parameters, variables, groups)
  - Format selection for quick run
  - Search and filtering
  - Quick run with default parameters
  """

  use AshReportsDemoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Reports")
     |> assign(:reports, load_reports())}
  end

  @impl true
  def handle_event("quick_run", %{"report" => report_name_str, "format" => format_str}, socket) do
    report_name = String.to_existing_atom(report_name_str)
    format = String.to_existing_atom(format_str)

    {:noreply,
     push_navigate(socket, to: ~p"/reports/#{report_name}?format=#{format}&auto_run=true")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-xl">
      <.header class="text-center">
        Available Reports
        <:subtitle>
          Explore comprehensive reports demonstrating AshReports pipeline features
        </:subtitle>
      </.header>
    </div>

    <div class="mt-8 space-y-6">
      <!-- Report Count -->
      <div class="text-sm text-white">
        <%= length(@reports) %> reports available
      </div>

      <!-- Report Grid -->
      <%= if Enum.empty?(@reports) do %>
        <div class="text-center py-12 bg-[#2F5597] rounded-lg">
          <svg class="mx-auto h-12 w-12 text-[#B4C6E7]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-white">No reports found</h3>
          <p class="mt-1 text-sm text-[#B4C6E7]">
            No reports are defined in the domain.
          </p>
        </div>
      <% else %>
        <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <div :for={report <- @reports} class="group relative flex flex-col rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow-md transition-shadow">
            <!-- Report Header -->
            <div class="p-6 flex-1">
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <h3 class="text-lg font-semibold text-gray-900">
                    <%= report.title %>
                  </h3>
                  <%= if report.description do %>
                    <p class="mt-2 text-sm text-gray-600 line-clamp-2">
                      <%= report.description %>
                    </p>
                  <% end %>
                </div>
              </div>

              <!-- Report Metadata -->
              <div class="mt-4 flex flex-wrap gap-3 text-xs">
                <div class="flex items-center text-gray-500">
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <span><%= report.param_count %> parameters</span>
                </div>
                <div class="flex items-center text-gray-500">
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
                  </svg>
                  <span><%= report.variable_count %> variables</span>
                </div>
                <%= if report.group_count > 0 do %>
                  <div class="flex items-center text-gray-500">
                    <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                    </svg>
                    <span><%= report.group_count %> groups</span>
                  </div>
                <% end %>
              </div>

              <!-- Quick Run Options -->
              <div class="mt-4 flex flex-wrap gap-2">
                <button
                  type="button"
                  phx-click="quick_run"
                  phx-value-report={report.name}
                  phx-value-format="html"
                  class="inline-flex items-center px-2 py-1 text-xs font-medium rounded border border-[#B4C6E7] text-gray-700 bg-white hover:bg-[#B4C6E7]"
                  title="Quick run with HTML format"
                >
                  HTML
                </button>
                <button
                  type="button"
                  phx-click="quick_run"
                  phx-value-report={report.name}
                  phx-value-format="json"
                  class="inline-flex items-center px-2 py-1 text-xs font-medium rounded border border-[#B4C6E7] text-gray-700 bg-white hover:bg-[#B4C6E7]"
                  title="Quick run with JSON format"
                >
                  JSON
                </button>
                <button
                  type="button"
                  phx-click="quick_run"
                  phx-value-report={report.name}
                  phx-value-format="heex"
                  class="inline-flex items-center px-2 py-1 text-xs font-medium rounded border border-[#B4C6E7] text-gray-700 bg-white hover:bg-[#B4C6E7]"
                  title="Quick run with HEEX format"
                >
                  HEEX
                </button>
              </div>
            </div>

            <!-- Report Footer -->
            <div class="border-t border-gray-200 bg-gray-50 px-6 py-4 rounded-b-lg">
              <.link
                navigate={~p"/reports/#{report.name}"}
                class="inline-flex items-center text-sm font-semibold text-[#4472C4] hover:text-[#2F5597]"
              >
                Configure & Run
                <svg class="ml-1 w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                </svg>
              </.link>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Private functions

  defp load_reports do
    # Get all reports from the domain using AshReports.Info
    reports = AshReports.Info.reports(AshReportsDemo.Domain)

    # Filter out reports that are temporarily disabled
    disabled_reports = [:financial_summary]

    reports
    |> Enum.reject(fn report -> report.name in disabled_reports end)
    |> Enum.map(&enrich_report_metadata/1)
  end

  defp enrich_report_metadata(report) do
    %{
      name: report.name,
      title: report.title || format_report_name(report.name),
      description: Map.get(report, :description),
      param_count: length(report.parameters),
      variable_count: length(report.variables),
      group_count: length(report.groups),
      band_count: length(report.bands),
      has_parameters: !Enum.empty?(report.parameters),
      parameters: report.parameters,
      variables: report.variables,
      groups: report.groups
    }
  end

  defp format_report_name(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
