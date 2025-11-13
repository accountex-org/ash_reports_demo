defmodule AshReportsDemoWeb.ChartLive.Viewer do
  @moduledoc """
  Individual chart viewer page that displays chart data and visualization.
  """

  use AshReportsDemoWeb, :live_view

  alias AshReportsDemo.Domain
  alias AshReportsDemoWeb.Components.ChartTemplateViewer

  @impl true
  def mount(%{"name" => chart_name_str}, _session, socket) do
    chart_name = String.to_existing_atom(chart_name_str)

    case AshReports.Info.chart(Domain, chart_name) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Chart not found: #{chart_name}")
         |> redirect(to: ~p"/charts")}

      chart_struct ->
        chart = %{
          name: chart_struct.name,
          type: chart_type_from_struct(chart_struct),
          title: get_chart_title(chart_struct),
          description: get_chart_description(chart_struct.name),
          struct: chart_struct
        }

        {:ok, initialize_viewer(socket, chart)}
    end
  rescue
    ArgumentError ->
      {:ok,
       socket
       |> put_flash(:error, "Invalid chart name: #{chart_name_str}")
       |> redirect(to: ~p"/charts")}
  end

  @impl true
  def handle_info(:execute_chart, socket) do
    {:noreply, execute_chart(socket)}
  end

  @impl true
  def handle_event("load_chart", _params, socket) do
    {:noreply, execute_chart(socket)}
  end

  @impl true
  def handle_event("refresh_chart", _params, socket) do
    {:noreply,
     socket
     |> assign(:loading, true)
     |> execute_chart()}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    active_tab = String.to_existing_atom(tab)
    {:noreply, assign(socket, :active_tab, active_tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-4">
      <.link navigate={~p"/charts"} class="text-sm font-medium text-white hover:text-[#B4C6E7]">
        ← Back to Charts
      </.link>
    </div>

    <div class="mx-auto max-w-xl">
      <.header class="text-center">
        <%= @chart.title %>
        <:subtitle>
          <%= @chart.description || "Interactive data visualization" %>
        </:subtitle>
      </.header>
    </div>

    <div class="mt-8">
      <div class="bg-white shadow rounded-lg overflow-hidden">
        <!-- Tab Navigation -->
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex" aria-label="Tabs">
            <button
              type="button"
              phx-click="switch_tab"
              phx-value-tab="chart"
              class={
                [
                  "w-1/2 py-4 px-1 text-center border-b-2 font-medium text-sm",
                  @active_tab == :chart && "border-[#4472C4] text-[#4472C4]",
                  @active_tab != :chart && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                ]
              }
            >
              Chart Visualization
            </button>
            <button
              type="button"
              phx-click="switch_tab"
              phx-value-tab="dsl"
              class={
                [
                  "w-1/2 py-4 px-1 text-center border-b-2 font-medium text-sm",
                  @active_tab == :dsl && "border-[#4472C4] text-[#4472C4]",
                  @active_tab != :dsl && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                ]
              }
            >
              Chart Definition (DSL)
            </button>
          </nav>
        </div>
        <!-- Tab Content -->
        <%= if @active_tab == :chart do %>
        <!-- Chart Header -->
        <div class="bg-gray-50 px-6 py-4 border-b border-gray-200">
          <div class="flex items-center gap-3">
            <span class={"inline-flex items-center px-3 py-1 rounded-full text-sm font-medium #{chart_type_color(@chart.type)}"}>
              <%= chart_type_name(@chart.type) %>
            </span>
            <%= if @data_loaded do %>
              <span class="text-sm text-gray-600">
                <%= length(@chart_data) %> data points
              </span>
            <% end %>
          </div>
        </div>

        <!-- Chart Content -->
        <div class="p-6">
          <%= if @loading do %>
            <div class="flex flex-col items-center justify-center py-12">
              <svg class="animate-spin h-12 w-12 text-blue-600 mb-4" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <p class="text-gray-600 font-medium">Processing chart data...</p>
            </div>
          <% else %>
            <%= if @error do %>
              <div class="bg-red-50 border border-red-200 rounded-lg p-4">
                <h3 class="text-red-900 font-semibold mb-2">Error Loading Chart</h3>
                <p class="text-red-700 text-sm"><%= @error %></p>
                <button
                  type="button"
                  phx-click="refresh_chart"
                  class="mt-4 inline-flex items-center px-3 py-2 border border-red-300 shadow-sm text-sm font-medium rounded-md text-red-700 bg-white hover:bg-red-50"
                >
                  Try Again
                </button>
              </div>
            <% else %>
              <%= if @data_loaded && @chart_svg do %>
                <!-- Record Count & Execution Time Display -->
                <%= if @source_records || @execution_time_ms do %>
                  <div class="mb-4 text-center">
                    <p class="text-sm text-gray-600">
                      <%= if @source_records do %>
                        Processed <span class="font-semibold text-gray-900"><%= format_number(@source_records) %></span> source <%= if @source_records == 1, do: "record", else: "records" %>
                      <% end %>
                      <%= if @source_records && @execution_time_ms do %>
                        <span class="mx-2">•</span>
                      <% end %>
                      <%= if @execution_time_ms do %>
                        <span class="font-semibold text-gray-900"><%= format_duration(@execution_time_ms) %></span>
                      <% end %>
                    </p>
                  </div>
                <% end %>

                <!-- AshReports Generated Chart -->
                <div class="bg-gray-50 rounded-lg p-6 flex items-center justify-center">
                  <div class="w-full">
                    <%= raw(@chart_svg) %>
                  </div>
                </div>

                <!-- Data Table -->
                <div class="mt-8">
                  <h4 class="text-sm font-semibold text-gray-900 mb-3">Chart Data</h4>
                  <div class="overflow-x-auto">
                    <table class="min-w-full divide-y divide-gray-200">
                      <thead class="bg-gray-50">
                        <tr>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            <%= if @chart.type == :pie, do: "Category", else: "Label" %>
                          </th>
                          <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Value</th>
                        </tr>
                      </thead>
                      <tbody class="bg-white divide-y divide-gray-200">
                        <%= for item <- @chart_data do %>
                          <tr>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                              <%= Map.get(item, :category) || Map.get(item, :x) %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-right">
                              <%= format_number(Map.get(item, :value) || Map.get(item, :y)) %>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                </div>
              <% else %>
                <div class="bg-gray-50 border-2 border-dashed border-gray-300 rounded-lg p-12 text-center">
                  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No data loaded</h3>
                  <p class="mt-1 text-sm text-gray-500">Click the button below to load chart data</p>
                  <button
                    type="button"
                    phx-click="load_chart"
                    class="mt-4 inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-[#4472C4] hover:bg-[#2F5597]"
                  >
                    Load Chart Data
                  </button>
                </div>
              <% end %>
            <% end %>
          <% end %>
        </div>
        <% end %>

        <%= if @active_tab == :dsl do %>
        <div class="p-6">
          <ChartTemplateViewer.chart_template_viewer chart_name={@chart.name} />
        </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp initialize_viewer(socket, chart) do
    # Send async message to load chart after mount completes
    send(self(), :execute_chart)

    socket
    |> assign(:page_title, chart.title)
    |> assign(:chart, chart)
    |> assign(:chart_svg, nil)
    |> assign(:chart_data, [])
    |> assign(:source_records, nil)
    |> assign(:execution_time_ms, nil)
    |> assign(:loading, true)
    |> assign(:data_loaded, false)
    |> assign(:error, nil)
    |> assign(:active_tab, :chart)
  end

  defp execute_chart(socket) do
    start_time = System.monotonic_time(:millisecond)

    chart = socket.assigns.chart
    chart_struct = chart.struct

    socket = assign(socket, :loading, true)

    # Fetch data using DataLoader + Transform pipeline with telemetry
    {data, metadata} =
      AshReportsDemoWeb.TelemetryInstrumentation.instrument_chart_data_query(
        AshReportsDemo.Domain,
        chart_struct,
        %{},
        fn ->
          case AshReports.Charts.DataLoader.load_chart_data(
                 AshReportsDemo.Domain,
                 chart_struct,
                 # params - TODO: pass actual params from assigns
                 %{}
               ) do
            {:ok, {records, meta}} ->
              # Extract transform from list (stored as entity, similar to config)
              transform_dsl =
                case chart_struct.transform do
                  [transform | _] -> transform
                  transform -> transform
                end

              # Convert TransformDSL to Transform struct, then execute
              case transform_dsl do
                %AshReports.Charts.TransformDSL{} = dsl ->
                  case AshReports.Charts.TransformDSL.to_transform(dsl) do
                    {:ok, transform} ->
                      # Apply transform to convert records to chart format
                      case AshReports.Charts.Transform.execute(records, transform) do
                        {:ok, chart_data} ->
                          # Convert atom keys to string keys, Decimals to floats for Contex compatibility
                          stringified_data =
                            Enum.map(chart_data, fn item ->
                              Map.new(item, fn
                                # Convert Decimal values to float
                                {k, %Decimal{} = v} ->
                                  {to_string(k), Decimal.to_float(v)}

                                # Convert atom values to string (for category fields in Gantt charts)
                                {k, v} when is_atom(v) and not is_nil(v) and not is_boolean(v) ->
                                  {to_string(k), to_string(v)}

                                # Convert month strings like "2024-12" to numeric (gregorian days)
                                # Contex cannot handle Date structs, only numbers
                                {k, v} when is_binary(v) and k in [:x, "x"] ->
                                  case parse_month_string(v) do
                                    {:ok, date} -> {to_string(k), Date.to_gregorian_days(date)}
                                    _ -> {to_string(k), v}
                                  end

                                # Keep other values as-is
                                {k, v} ->
                                  {to_string(k), v}
                              end)
                            end)

                          {{stringified_data, meta}, %{data_points: length(stringified_data)}}

                        {:error, reason} ->
                          {{[], meta}, %{error: reason}}
                      end

                    {:error, reason} ->
                      {{[], meta}, %{error: reason}}
                  end

                nil ->
                  {{[], meta}, %{error: "No transform defined"}}

                _other ->
                  {{[], meta}, %{error: "Unexpected transform type"}}
              end

            {:error, reason} ->
              {{[], %{}}, %{error: reason}}
          end
        end
      )

    # Extract config
    config =
      case chart_struct.config do
        [config_struct | _] when is_map(config_struct) -> config_struct
        _ -> %{}
      end

    # Get chart type atom for generate function
    chart_type = chart_type_atom(chart.type)

    # Generate chart using AshReports with telemetry
    case AshReportsDemoWeb.TelemetryInstrumentation.instrument_chart_generation(
           chart_type,
           data,
           config,
           fn ->
             {AshReports.Charts.generate(chart_type, data, config), %{data_points: length(data)}}
           end
         ) do
      {:ok, svg} ->
        execution_time_ms = System.monotonic_time(:millisecond) - start_time

        socket
        |> assign(:chart_svg, svg)
        |> assign(:chart_data, data)
        |> assign(:source_records, Map.get(metadata, :source_records))
        |> assign(:execution_time_ms, execution_time_ms)
        |> assign(:data_loaded, true)
        |> assign(:loading, false)
        |> assign(:error, nil)

      {:error, reason} ->
        socket
        |> assign(:loading, false)
        |> assign(:error, inspect(reason))
    end
  rescue
    error ->
      socket
      |> assign(:loading, false)
      |> assign(:error, "Error generating chart: #{Exception.message(error)}")
  end

  defp chart_type_color(:line_chart), do: "bg-blue-100 text-blue-800"
  defp chart_type_color(:bar_chart), do: "bg-green-100 text-green-800"
  defp chart_type_color(:pie_chart), do: "bg-purple-100 text-purple-800"
  defp chart_type_color(:area_chart), do: "bg-orange-100 text-orange-800"
  defp chart_type_color(:scatter_chart), do: "bg-pink-100 text-pink-800"
  defp chart_type_color(:gantt_chart), do: "bg-indigo-100 text-indigo-800"
  defp chart_type_color(:sparkline), do: "bg-teal-100 text-teal-800"
  defp chart_type_color(_), do: "bg-gray-100 text-gray-800"

  defp chart_type_name(:line_chart), do: "Line Chart"
  defp chart_type_name(:bar_chart), do: "Bar Chart"
  defp chart_type_name(:pie_chart), do: "Pie Chart"
  defp chart_type_name(:area_chart), do: "Area Chart"
  defp chart_type_name(:scatter_chart), do: "Scatter Chart"
  defp chart_type_name(:gantt_chart), do: "Gantt Chart"
  defp chart_type_name(:sparkline), do: "Sparkline"
  defp chart_type_name(_), do: "Chart"

  defp format_number(num) when is_float(num), do: :erlang.float_to_binary(num, decimals: 2)
  defp format_number(num) when is_integer(num), do: Integer.to_string(num)
  defp format_number(num) when is_list(num), do: "#{length(num)} values"
  defp format_number(num), do: to_string(num)

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 2)}s"
  defp format_duration(ms), do: "#{Float.round(ms / 60_000, 1)}min"

  # Helper functions for chart struct handling

  defp chart_type_from_struct(%AshReports.Charts.PieChart{}), do: :pie_chart
  defp chart_type_from_struct(%AshReports.Charts.BarChart{}), do: :bar_chart
  defp chart_type_from_struct(%AshReports.Charts.LineChart{}), do: :line_chart
  defp chart_type_from_struct(%AshReports.Charts.AreaChart{}), do: :area_chart
  defp chart_type_from_struct(%AshReports.Charts.ScatterChart{}), do: :scatter_chart
  defp chart_type_from_struct(%AshReports.Charts.GanttChart{}), do: :gantt_chart
  defp chart_type_from_struct(%AshReports.Charts.Sparkline{}), do: :sparkline
  defp chart_type_from_struct(_), do: :unknown

  defp chart_type_atom(:pie_chart), do: :pie
  defp chart_type_atom(:bar_chart), do: :bar
  defp chart_type_atom(:line_chart), do: :line
  defp chart_type_atom(:area_chart), do: :area
  defp chart_type_atom(:scatter_chart), do: :scatter
  defp chart_type_atom(:gantt_chart), do: :gantt
  defp chart_type_atom(:sparkline), do: :sparkline
  defp chart_type_atom(_), do: :bar

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

  defp get_chart_description(_), do: "Chart visualization"

  # Parse month string like "2024-12" to Date (first day of month)
  defp parse_month_string(str) when is_binary(str) do
    case String.split(str, "-") do
      [year_str, month_str] ->
        with {year, ""} <- Integer.parse(year_str),
             {month, ""} <- Integer.parse(month_str),
             {:ok, date} <- Date.new(year, month, 1) do
          {:ok, date}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp parse_month_string(_), do: :error
end
