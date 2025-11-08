defmodule AshReportsDemoWeb.ChartLive.Index do
  @moduledoc """
  Chart listing page that displays all available charts.
  """

  use AshReportsDemoWeb, :live_view

  alias AshReportsDemo.Domain

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Charts")
     |> assign(:charts, load_charts())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-xl">
      <.header class="text-center">
        Available Charts
        <:subtitle>
          Explore data visualizations for comprehensive business insights
        </:subtitle>
      </.header>
    </div>

    <div class="mt-8 space-y-6">
      <!-- Chart Count -->
      <div class="text-sm text-white">
        <%= length(@charts) %> charts available
      </div>

      <!-- Chart Grid -->
      <%= if Enum.empty?(@charts) do %>
        <div class="text-center py-12 bg-[#2F5597] rounded-lg">
          <svg class="mx-auto h-12 w-12 text-[#B4C6E7]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-white">No charts found</h3>
          <p class="mt-1 text-sm text-[#B4C6E7]">
            No charts are defined in the domain.
          </p>
        </div>
      <% else %>
        <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <div :for={chart <- @charts} class="group relative flex flex-col rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow-md transition-shadow">
            <!-- Chart Header -->
            <div class="p-6 flex-1">
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <div class="flex items-center gap-2">
                    <h3 class="text-lg font-semibold text-gray-900">
                      <%= chart.title %>
                    </h3>
                    <%= chart_type_badge(chart.type) %>
                  </div>
                  <%= if chart.description do %>
                    <p class="mt-2 text-sm text-gray-600 line-clamp-2">
                      <%= chart.description %>
                    </p>
                  <% end %>
                </div>
              </div>

              <!-- Chart Icon -->
              <.link
                navigate={~p"/charts/#{chart.name}"}
                class="mt-4 flex items-center justify-center py-8 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors cursor-pointer"
              >
                <%= chart_icon(chart.type) %>
              </.link>
            </div>

            <!-- Chart Footer -->
            <div class="border-t border-gray-200 bg-gray-50 px-6 py-4 rounded-b-lg">
              <.link
                navigate={~p"/charts/#{chart.name}"}
                class="inline-flex items-center text-sm font-semibold text-[#4472C4] hover:text-[#2F5597]"
              >
                View Chart
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

  defp load_charts do
    Domain
    |> AshReports.Info.charts()
    |> Enum.map(fn chart_struct ->
      %{
        name: chart_struct.name,
        type: chart_type_from_struct(chart_struct),
        title: get_chart_title(chart_struct),
        description: get_chart_description(chart_struct.name)
      }
    end)
  end

  defp chart_type_from_struct(%AshReports.Charts.PieChart{}), do: :pie_chart
  defp chart_type_from_struct(%AshReports.Charts.BarChart{}), do: :bar_chart
  defp chart_type_from_struct(%AshReports.Charts.LineChart{}), do: :line_chart
  defp chart_type_from_struct(%AshReports.Charts.AreaChart{}), do: :area_chart
  defp chart_type_from_struct(%AshReports.Charts.ScatterChart{}), do: :scatter_chart
  defp chart_type_from_struct(%AshReports.Charts.GanttChart{}), do: :gantt_chart
  defp chart_type_from_struct(%AshReports.Charts.Sparkline{}), do: :sparkline
  defp chart_type_from_struct(_), do: :unknown

  defp get_chart_title(chart_struct) do
    case chart_struct.config do
      [config | _] when is_map(config) -> Map.get(config, :title, "Untitled Chart")
      _ -> "Untitled Chart"
    end
  end

  defp get_chart_description(:customer_status_distribution),
    do: "Visual breakdown of customer base by status (Active, Inactive, Suspended)"

  defp get_chart_description(:monthly_revenue),
    do: "Revenue trends across months showing business growth patterns"

  defp get_chart_description(:product_sales_by_category),
    do: "Comparative sales performance across product categories"

  defp get_chart_description(:top_products_by_revenue),
    do: "Top 10 revenue-generating products ranked by total sales"

  defp get_chart_description(:inventory_levels_over_time),
    do: "Stock level trends showing inventory health over time"

  defp get_chart_description(:price_quantity_analysis),
    do: "Correlation analysis between product pricing and sales quantity"

  defp get_chart_description(:invoice_payment_timeline),
    do: "Timeline visualization of invoice issuance and payment schedules"

  defp get_chart_description(:customer_health_trend),
    do: "Compact trend indicator for customer health score over time"

  defp get_chart_description(_), do: "Chart visualization"

  defp chart_type_badge(type) do
    {color, text} =
      case type do
        :line_chart -> {"bg-blue-100 text-blue-800", "Line"}
        :bar_chart -> {"bg-green-100 text-green-800", "Bar"}
        :pie_chart -> {"bg-purple-100 text-purple-800", "Pie"}
        :area_chart -> {"bg-orange-100 text-orange-800", "Area"}
        :scatter_chart -> {"bg-pink-100 text-pink-800", "Scatter"}
        :gantt_chart -> {"bg-indigo-100 text-indigo-800", "Gantt"}
        :sparkline -> {"bg-teal-100 text-teal-800", "Sparkline"}
        _ -> {"bg-gray-100 text-gray-800", "Chart"}
      end

    assigns = %{color: color, text: text}

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@color}"}>
      <%= @text %>
    </span>
    """
  end

  defp chart_icon(:line_chart) do
    assigns = %{}

    ~H"""
    <svg class="w-16 h-16 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z" />
    </svg>
    """
  end

  defp chart_icon(:bar_chart) do
    assigns = %{}

    ~H"""
    <svg class="w-16 h-16 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
    </svg>
    """
  end

  defp chart_icon(:pie_chart) do
    assigns = %{}

    ~H"""
    <svg class="w-16 h-16 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z" />
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z" />
    </svg>
    """
  end

  defp chart_icon(:area_chart) do
    assigns = %{}

    ~H"""
    <svg class="w-16 h-16 text-orange-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z" />
    </svg>
    """
  end

  defp chart_icon(:scatter_chart) do
    assigns = %{}

    ~H"""
    <svg class="w-16 h-16 text-pink-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01" />
    </svg>
    """
  end

  defp chart_icon(:gantt_chart) do
    assigns = %{}

    ~H"""
    <svg class="w-16 h-16 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
    </svg>
    """
  end

  defp chart_icon(:sparkline) do
    assigns = %{}

    ~H"""
    <svg class="w-16 h-16 text-teal-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
    </svg>
    """
  end

  defp chart_icon(_) do
    assigns = %{}

    ~H"""
    <svg class="w-16 h-16 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 8v8m-4-5v5m-4-2v2m-2 4h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
    </svg>
    """
  end
end
