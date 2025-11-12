defmodule AshReportsDemoWeb.TelemetryInstrumentation do
  @moduledoc """
  Telemetry instrumentation for chart and report generation.
  
  Provides functions to wrap chart and report operations with telemetry events,
  tracking data queries and generation separately.
  """

  @doc """
  Wraps chart data loading with telemetry events.
  """
  def instrument_chart_data_query(domain, chart_struct, params, fun) do
    metadata = %{
      chart_name: chart_struct.name,
      chart_type: chart_type_from_struct(chart_struct),
      domain: domain,
      params: params
    }

    :telemetry.span(
      [:ash_reports, :charts, :data_query],
      metadata,
      fun
    )
  end

  @doc """
  Wraps chart generation with telemetry events.
  """
  def instrument_chart_generation(chart_type, data, config, fun) do
    metadata = %{
      chart_type: chart_type,
      data_points: length(data),
      config: config
    }

    :telemetry.span(
      [:ash_reports, :charts, :generate],
      metadata,
      fun
    )
  end

  @doc """
  Wraps report data loading with telemetry events.
  """
  def instrument_report_data_query(domain, report_struct, params, fun) do
    metadata = %{
      report_name: report_struct.name,
      domain: domain,
      params: params
    }

    :telemetry.span(
      [:ash_reports, :reports, :data_query],
      metadata,
      fun
    )
  end

  @doc """
  Wraps report generation with telemetry events.
  """
  def instrument_report_generation(format, data, config, fun) do
    metadata = %{
      format: format,
      data_points: length(data),
      config: config
    }

    :telemetry.span(
      [:ash_reports, :reports, :generate],
      metadata,
      fun
    )
  end

  @doc """
  Emits cache hit event for charts.
  """
  def emit_chart_cache_hit(chart_name, chart_type) do
    :telemetry.execute(
      [:ash_reports, :charts, :cache, :hit],
      %{count: 1},
      %{chart_name: chart_name, chart_type: chart_type}
    )
  end

  @doc """
  Emits cache miss event for charts.
  """
  def emit_chart_cache_miss(chart_name, chart_type) do
    :telemetry.execute(
      [:ash_reports, :charts, :cache, :miss],
      %{count: 1},
      %{chart_name: chart_name, chart_type: chart_type}
    )
  end

  @doc """
  Emits cache hit event for reports.
  """
  def emit_report_cache_hit(report_name, format) do
    :telemetry.execute(
      [:ash_reports, :reports, :cache, :hit],
      %{count: 1},
      %{report_name: report_name, format: format}
    )
  end

  @doc """
  Emits cache miss event for reports.
  """
  def emit_report_cache_miss(report_name, format) do
    :telemetry.execute(
      [:ash_reports, :reports, :cache, :miss],
      %{count: 1},
      %{report_name: report_name, format: format}
    )
  end

  defp chart_type_from_struct(%AshReports.Charts.PieChart{}), do: :pie_chart
  defp chart_type_from_struct(%AshReports.Charts.BarChart{}), do: :bar_chart
  defp chart_type_from_struct(%AshReports.Charts.LineChart{}), do: :line_chart
  defp chart_type_from_struct(%AshReports.Charts.AreaChart{}), do: :area_chart
  defp chart_type_from_struct(%AshReports.Charts.ScatterChart{}), do: :scatter_chart
  defp chart_type_from_struct(%AshReports.Charts.GanttChart{}), do: :gantt_chart
  defp chart_type_from_struct(%AshReports.Charts.Sparkline{}), do: :sparkline
  defp chart_type_from_struct(_), do: :unknown
end