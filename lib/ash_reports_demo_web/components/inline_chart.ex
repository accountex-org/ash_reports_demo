defmodule AshReportsDemoWeb.Components.InlineChart do
  @moduledoc """
  LiveComponent for rendering charts directly inline in other views.

  Handles chart data loading and displays appropriate messages when no data exists.
  """

  use AshReportsDemoWeb, :live_component

  alias AshReportsDemo.Domain

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Get chart_name either from assigns or from chart_struct.name
    chart_name =
      Map.get(assigns, :chart_name) ||
        (Map.get(assigns, :chart_struct) && Map.get(assigns.chart_struct, :name))

    case chart_name do
      nil ->
        {:ok,
         socket
         |> assign(assigns)
         |> assign(:error, "Chart name not provided")
         |> assign(:loading, false)
         |> assign(:chart_svg, nil)
         |> assign(:chart_data, [])}

      _ ->
        case AshReports.Info.chart(Domain, chart_name) do
          nil ->
            {:ok,
             socket
             |> assign(assigns)
             |> assign(:error, "Chart not found: #{chart_name}")
             |> assign(:loading, false)
             |> assign(:chart_svg, nil)
             |> assign(:chart_data, [])}

          chart_struct ->
            # If we already have the chart_struct in assigns, use it
            chart_to_use = Map.get(assigns, :chart_struct, chart_struct)

            # Execute chart directly instead of sending async message
            socket =
              socket
              |> assign(assigns)
              |> assign(:chart_struct, chart_to_use)
              |> assign(:chart_name, chart_name)
              |> assign(:loading, true)
              |> assign(:error, nil)
              |> assign(:chart_svg, nil)
              |> assign(:chart_data, [])

            # Execute chart immediately
            socket = execute_chart(socket, chart_to_use)

            {:ok, socket}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="inline-chart-container">
      <%= cond do %>
        <% @loading -> %>
          <div class="flex flex-col items-center justify-center py-8">
            <svg class="animate-spin h-8 w-8 text-white/60 mb-3" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <p class="text-white/80 text-sm">Loading chart data...</p>
          </div>
          
        <% @error -> %>
          <div class="text-center py-8">
            <svg class="mx-auto h-12 w-12 text-white/40 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <h4 class="text-white font-medium mb-2">Chart Error</h4>
            <p class="text-[#B4C6E7] text-sm"><%= @error %></p>
          </div>
          
        <% length(@chart_data) == 0 && !@loading -> %>
          <div class="text-center py-8">
            <svg class="mx-auto h-12 w-12 text-white/40 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
            <h4 class="text-white font-medium mb-2">No Analytics Data</h4>
            <p class="text-[#B4C6E7] text-sm mb-3">Session analytics data is not available yet.</p>
            <p class="text-[#B4C6E7] text-xs">Charts will appear as session data is collected over time.</p>
          </div>
          
        <% @chart_svg -> %>
          <div class="bg-white rounded-lg p-4">
            <%= raw(@chart_svg) %>
          </div>
          <%= if length(@chart_data) > 0 do %>
            <div class="mt-3 text-center">
              <p class="text-[#B4C6E7] text-xs">
                <%= length(@chart_data) %> data points
              </p>
            </div>
          <% end %>
          
        <% true -> %>
          <div class="text-center py-8">
            <svg class="mx-auto h-12 w-12 text-white/40 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
            <h4 class="text-white font-medium mb-2">Chart Unavailable</h4>
            <p class="text-[#B4C6E7] text-sm">Unable to load chart data at this time.</p>
          </div>
      <% end %>
    </div>
    """
  end

  defp execute_chart(socket, chart_struct) do
    # Load chart data using the same system as ChartLive.Viewer
    {data, _metadata} =
      AshReportsDemoWeb.TelemetryInstrumentation.instrument_chart_data_query(
        AshReportsDemo.Domain,
        chart_struct,
        %{},
        fn ->
          case AshReports.Charts.DataLoader.load_chart_data(
                 AshReportsDemo.Domain,
                 chart_struct,
                 %{}
               ) do
            {:ok, {records, meta}} ->
              # Extract and execute transform
              transform_dsl =
                case chart_struct.transform do
                  [transform | _] -> transform
                  transform -> transform
                end

              case transform_dsl do
                %AshReports.Charts.TransformDSL{} = dsl ->
                  case AshReports.Charts.TransformDSL.to_transform(dsl) do
                    {:ok, transform} ->
                      case AshReports.Charts.Transform.execute(records, transform) do
                        {:ok, chart_data} ->
                          # Convert for Contex compatibility
                          stringified_data =
                            Enum.map(chart_data, fn item ->
                              Map.new(item, fn
                                {k, %Decimal{} = v} ->
                                  {to_string(k), Decimal.to_float(v)}

                                {k, v} when is_atom(v) and not is_nil(v) and not is_boolean(v) ->
                                  {to_string(k), to_string(v)}

                                # Convert DateTime values to unix timestamp for x-axis
                                {k, %DateTime{} = v} when k in [:x, "x"] ->
                                  {to_string(k), DateTime.to_unix(v)}

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
                  {{[], meta}, %{error: "Invalid transform"}}
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

    # Get chart type
    chart_type = chart_type_atom(chart_struct)

    # Generate SVG with telemetry
    case AshReportsDemoWeb.TelemetryInstrumentation.instrument_chart_generation(
           chart_type,
           data,
           config,
           fn ->
             {AshReports.Charts.generate(chart_type, data, config), %{data_points: length(data)}}
           end
         ) do
      {:ok, svg} ->
        socket
        |> assign(:chart_svg, svg)
        |> assign(:chart_data, data)
        |> assign(:loading, false)
        |> assign(:error, nil)

      {:error, reason} ->
        socket
        |> assign(:loading, false)
        |> assign(:error, "Error generating chart: #{inspect(reason)}")
    end
  rescue
    error ->
      socket
      |> assign(:loading, false)
      |> assign(:error, "Chart error: #{Exception.message(error)}")
  end

  defp chart_type_atom(%AshReports.Charts.PieChart{}), do: :pie
  defp chart_type_atom(%AshReports.Charts.BarChart{}), do: :bar
  defp chart_type_atom(%AshReports.Charts.LineChart{}), do: :line
  defp chart_type_atom(%AshReports.Charts.AreaChart{}), do: :area
  defp chart_type_atom(%AshReports.Charts.ScatterChart{}), do: :scatter
  defp chart_type_atom(%AshReports.Charts.GanttChart{}), do: :gantt
  defp chart_type_atom(%AshReports.Charts.Sparkline{}), do: :sparkline
  defp chart_type_atom(_), do: :bar
end
