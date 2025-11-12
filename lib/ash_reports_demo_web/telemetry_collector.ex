defmodule AshReportsDemoWeb.TelemetryCollector do
  @moduledoc """
  Collects telemetry events for dashboard metrics.
  
  Tracks application performance, user interactions, and system health.
  """
  
  use GenServer
  require Logger

  @table_name :telemetry_collector_metrics
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Gets collected telemetry metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end
  
  @doc """
  Gets performance statistics.
  """
  def get_performance_stats do
    GenServer.call(__MODULE__, :get_performance_stats)
  end
  
  @impl true
  def init(_opts) do
    # Create ETS table for storing metrics
    # Table must be :public since telemetry handlers run in different processes
    table = :ets.new(@table_name, [:set, :public, :named_table])
    
    # Initialize counters
    initial_metrics = %{
      # Request metrics
      total_requests: 0,
      avg_request_time: 0.0,
      error_count: 0,
      
      # LiveView metrics
      lv_mounts: 0,
      lv_events: 0,
      avg_mount_time: 0.0,
      
      # Chart metrics
      charts_generated: 0,
      chart_cache_hits: 0,
      chart_cache_misses: 0,
      avg_chart_generation_time: 0.0,
      
      # Chart data query metrics
      chart_data_queries: 0,
      avg_chart_data_query_time: 0.0,
      
      # Report metrics
      reports_generated: 0,
      report_cache_hits: 0,
      report_cache_misses: 0,
      avg_report_generation_time: 0.0,
      
      # Report data query metrics
      report_data_queries: 0,
      avg_report_data_query_time: 0.0,
      
      # Socket metrics
      socket_connections: 0,
      
      # Timing data for averages
      request_times: [],
      mount_times: [],
      chart_generation_times: [],
      chart_data_query_times: [],
      report_generation_times: [],
      report_data_query_times: []
    }
    
    :ets.insert(@table_name, {:metrics, initial_metrics})
    
    # Attach telemetry handlers
    attach_handlers()
    
    Logger.info("TelemetryCollector started with handlers attached")
    {:ok, %{table: table}}
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    case :ets.lookup(@table_name, :metrics) do
      [{:metrics, metrics}] -> {:reply, metrics, state}
      [] -> {:reply, %{}, state}
    end
  end
  
  @impl true
  def handle_call(:get_performance_stats, _from, state) do
    case :ets.lookup(@table_name, :metrics) do
      [{:metrics, metrics}] ->
        stats = %{
          requests_per_second: calculate_requests_per_second(metrics),
          error_rate: calculate_error_rate(metrics),
          cache_hit_rate: calculate_cache_hit_rate(metrics),
          performance_score: calculate_performance_score(metrics)
        }
        {:reply, stats, state}
      [] -> 
        {:reply, %{requests_per_second: 0, error_rate: 0, cache_hit_rate: 0, performance_score: 0}, state}
    end
  end
  
  defp attach_handlers do
    # Phoenix endpoint events
    :telemetry.attach(
      "endpoint-stop",
      [:phoenix, :endpoint, :stop],
      &__MODULE__.handle_endpoint_stop/4,
      nil
    )
    
    # LiveView mount events
    :telemetry.attach(
      "lv-mount-stop", 
      [:phoenix, :live_view, :mount, :stop],
      &__MODULE__.handle_lv_mount_stop/4,
      nil
    )
    
    # LiveView event handling
    :telemetry.attach(
      "lv-handle-event-stop",
      [:phoenix, :live_view, :handle_event, :stop], 
      &__MODULE__.handle_lv_event_stop/4,
      nil
    )
    
    # Chart data query events
    :telemetry.attach(
      "chart-data-query-start",
      [:ash_reports, :charts, :data_query, :start],
      &__MODULE__.handle_chart_data_query_start/4,
      nil
    )
    
    :telemetry.attach(
      "chart-data-query-stop",
      [:ash_reports, :charts, :data_query, :stop],
      &__MODULE__.handle_chart_data_query_stop/4,
      nil
    )
    
    # Chart generation events
    :telemetry.attach(
      "chart-generate-start",
      [:ash_reports, :charts, :generate, :start],
      &__MODULE__.handle_chart_generate_start/4,
      nil
    )
    
    # Chart generation events
    :telemetry.attach(
      "chart-generate-stop",
      [:ash_reports, :charts, :generate, :stop],
      &__MODULE__.handle_chart_generate_stop/4,
      nil
    )
    
    # Report data query events
    :telemetry.attach(
      "report-data-query-start",
      [:ash_reports, :reports, :data_query, :start],
      &__MODULE__.handle_report_data_query_start/4,
      nil
    )
    
    :telemetry.attach(
      "report-data-query-stop",
      [:ash_reports, :reports, :data_query, :stop],
      &__MODULE__.handle_report_data_query_stop/4,
      nil
    )
    
    # Report generation events
    :telemetry.attach(
      "report-generate-start",
      [:ash_reports, :reports, :generate, :start],
      &__MODULE__.handle_report_generate_start/4,
      nil
    )
    
    :telemetry.attach(
      "report-generate-stop",
      [:ash_reports, :reports, :generate, :stop],
      &__MODULE__.handle_report_generate_stop/4,
      nil
    )
    
    # Chart cache events
    :telemetry.attach(
      "chart-cache-hit",
      [:ash_reports, :charts, :cache, :hit],
      &__MODULE__.handle_chart_cache_hit/4,
      nil
    )
    
    :telemetry.attach(
      "chart-cache-miss",
      [:ash_reports, :charts, :cache, :miss],
      &__MODULE__.handle_chart_cache_miss/4,
      nil
    )
    
    # Report cache events
    :telemetry.attach(
      "report-cache-hit",
      [:ash_reports, :reports, :cache, :hit],
      &__MODULE__.handle_report_cache_hit/4,
      nil
    )
    
    :telemetry.attach(
      "report-cache-miss",
      [:ash_reports, :reports, :cache, :miss],
      &__MODULE__.handle_report_cache_miss/4,
      nil
    )
    
    # Socket connections
    :telemetry.attach(
      "socket-connected",
      [:phoenix, :socket_connected],
      &__MODULE__.handle_socket_connected/4,
      nil
    )
    
    # Error events
    :telemetry.attach(
      "error-rendered",
      [:phoenix, :error_rendered],
      &__MODULE__.handle_error_rendered/4,
      nil
    )
  end
  
  # Telemetry event handlers
  
  def handle_endpoint_stop(_event_name, measurements, _metadata, _config) do
    duration = measurements[:duration]
    update_metrics(fn metrics ->
      new_request_times = [duration | Enum.take(metrics.request_times, 99)] # Keep last 100
      avg_time = Enum.sum(new_request_times) / length(new_request_times) / 1_000_000 # Convert to ms

      %{metrics |
        total_requests: metrics.total_requests + 1,
        request_times: new_request_times,
        avg_request_time: avg_time
      }
    end)
  end

  def handle_lv_mount_stop(_event_name, measurements, _metadata, _config) do
    duration = measurements[:duration]
    update_metrics(fn metrics ->
      new_mount_times = [duration | Enum.take(metrics.mount_times, 99)]
      avg_time = if length(new_mount_times) > 0 do
        Enum.sum(new_mount_times) / length(new_mount_times) / 1_000_000
      else
        0.0
      end

      %{metrics |
        lv_mounts: metrics.lv_mounts + 1,
        mount_times: new_mount_times,
        avg_mount_time: avg_time
      }
    end)
  end

  def handle_lv_event_stop(_event_name, _measurements, _metadata, _config) do
    update_metrics(fn metrics ->
      %{metrics | lv_events: metrics.lv_events + 1}
    end)
  end

  def handle_chart_data_query_start(_event_name, _measurements, _metadata, _config) do
    # For start events, we mainly log but don't update metrics yet
    # The actual metrics update happens in the stop event
    :ok
  end
  
  def handle_chart_data_query_stop(_event_name, measurements, metadata, _config) do
    duration = measurements[:duration]
    chart_name = metadata[:chart_name] || "unknown"
    chart_type = metadata[:chart_type] || "unknown"
    
    # Store telemetry event in Ash resource
    try do
      AshReportsDemo.Resources.TelemetryEvent.create!(:chart_data_query, to_string(chart_name), duration, %{
        operation_type: to_string(chart_type),
        data_points: Map.get(metadata, :data_points, 0),
        success: !Map.has_key?(metadata, :error),
        error_message: Map.get(metadata, :error),
        metadata: metadata
      })
    rescue
      _ -> :ok
    end
    
    # Update in-memory metrics
    update_metrics(fn metrics ->
      new_query_times = [duration | Enum.take(metrics.chart_data_query_times, 99)]
      avg_time = if length(new_query_times) > 0 do
        Enum.sum(new_query_times) / length(new_query_times) / 1_000_000
      else
        0.0
      end
      
      %{metrics |
        chart_data_queries: metrics.chart_data_queries + 1,
        chart_data_query_times: new_query_times,
        avg_chart_data_query_time: avg_time
      }
    end)
  end
  
  def handle_chart_generate_start(_event_name, _measurements, _metadata, _config) do
    # For start events, we mainly log but don't update metrics yet
    :ok
  end

  def handle_chart_generate_stop(_event_name, measurements, metadata, _config) do
    duration = measurements[:duration]
    chart_type = metadata[:chart_type] || "unknown"
    
    # Store telemetry event in Ash resource
    try do
      AshReportsDemo.Resources.TelemetryEvent.create!(:chart_generate, to_string(chart_type), duration, %{
        operation_type: to_string(chart_type),
        data_points: Map.get(metadata, :data_points, 0),
        success: !Map.has_key?(metadata, :error),
        error_message: Map.get(metadata, :error),
        metadata: metadata
      })
    rescue
      _ -> :ok
    end
    
    # Update in-memory metrics
    update_metrics(fn metrics ->
      new_generation_times = [duration | Enum.take(metrics.chart_generation_times, 99)]
      avg_time = if length(new_generation_times) > 0 do
        Enum.sum(new_generation_times) / length(new_generation_times) / 1_000_000
      else
        0.0
      end
      
      %{metrics |
        charts_generated: metrics.charts_generated + 1,
        chart_generation_times: new_generation_times,
        avg_chart_generation_time: avg_time
      }
    end)
  end
  
  def handle_report_data_query_start(_event_name, _measurements, _metadata, _config) do
    :ok
  end
  
  def handle_report_data_query_stop(_event_name, measurements, metadata, _config) do
    duration = measurements[:duration]
    report_name = metadata[:report_name] || "unknown"
    
    # Store telemetry event in Ash resource
    try do
      AshReportsDemo.Resources.TelemetryEvent.create!(:report_data_query, to_string(report_name), duration, %{
        data_points: Map.get(metadata, :data_points, 0),
        success: !Map.has_key?(metadata, :error),
        error_message: Map.get(metadata, :error),
        metadata: metadata
      })
    rescue
      _ -> :ok
    end
    
    # Update in-memory metrics
    update_metrics(fn metrics ->
      new_query_times = [duration | Enum.take(metrics.report_data_query_times, 99)]
      avg_time = if length(new_query_times) > 0 do
        Enum.sum(new_query_times) / length(new_query_times) / 1_000_000
      else
        0.0
      end
      
      %{metrics |
        report_data_queries: metrics.report_data_queries + 1,
        report_data_query_times: new_query_times,
        avg_report_data_query_time: avg_time
      }
    end)
  end
  
  def handle_report_generate_start(_event_name, _measurements, _metadata, _config) do
    :ok
  end
  
  def handle_report_generate_stop(_event_name, measurements, metadata, _config) do
    duration = measurements[:duration]
    format = metadata[:format] || "unknown"
    
    # Store telemetry event in Ash resource
    try do
      AshReportsDemo.Resources.TelemetryEvent.create!(:report_generate, to_string(format), duration, %{
        operation_type: to_string(format),
        data_points: Map.get(metadata, :data_points, 0),
        success: !Map.has_key?(metadata, :error),
        error_message: Map.get(metadata, :error),
        metadata: metadata
      })
    rescue
      _ -> :ok
    end
    
    # Update in-memory metrics
    update_metrics(fn metrics ->
      new_generation_times = [duration | Enum.take(metrics.report_generation_times, 99)]
      avg_time = if length(new_generation_times) > 0 do
        Enum.sum(new_generation_times) / length(new_generation_times) / 1_000_000
      else
        0.0
      end
      
      %{metrics |
        reports_generated: metrics.reports_generated + 1,
        report_generation_times: new_generation_times,
        avg_report_generation_time: avg_time
      }
    end)
  end
  
  def handle_chart_cache_hit(_event_name, _measurements, _metadata, _config) do
    update_metrics(fn metrics ->
      %{metrics | chart_cache_hits: metrics.chart_cache_hits + 1}
    end)
  end

  def handle_chart_cache_miss(_event_name, _measurements, _metadata, _config) do
    update_metrics(fn metrics ->
      %{metrics | chart_cache_misses: metrics.chart_cache_misses + 1}
    end)
  end

  def handle_report_cache_hit(_event_name, _measurements, _metadata, _config) do
    update_metrics(fn metrics ->
      %{metrics | report_cache_hits: metrics.report_cache_hits + 1}
    end)
  end

  def handle_report_cache_miss(_event_name, _measurements, _metadata, _config) do
    update_metrics(fn metrics ->
      %{metrics | report_cache_misses: metrics.report_cache_misses + 1}
    end)
  end

  def handle_socket_connected(_event_name, _measurements, _metadata, _config) do
    update_metrics(fn metrics ->
      %{metrics | socket_connections: metrics.socket_connections + 1}
    end)
  end

  def handle_error_rendered(_event_name, _measurements, _metadata, _config) do
    update_metrics(fn metrics ->
      %{metrics | error_count: metrics.error_count + 1}
    end)
  end
  
  defp update_metrics(update_fn) do
    case :ets.lookup(@table_name, :metrics) do
      [{:metrics, current_metrics}] ->
        new_metrics = update_fn.(current_metrics)
        :ets.insert(@table_name, {:metrics, new_metrics})
      [] ->
        Logger.warning("No metrics found in ETS table")
    end
  end
  
  # Calculation helpers
  
  defp calculate_requests_per_second(metrics) do
    # Simple estimation - could be enhanced with time windows
    if metrics.total_requests > 0 and metrics.avg_request_time > 0 do
      Float.round(1000 / metrics.avg_request_time, 2)
    else
      0
    end
  end
  
  defp calculate_error_rate(metrics) do
    if metrics.total_requests > 0 do
      Float.round(metrics.error_count / metrics.total_requests * 100, 2)
    else
      0
    end
  end
  
  defp calculate_cache_hit_rate(metrics) do
    total_cache_requests = metrics.chart_cache_hits + metrics.chart_cache_misses
    if total_cache_requests > 0 do
      Float.round(metrics.chart_cache_hits / total_cache_requests * 100, 2)
    else
      0
    end
  end
  
  defp calculate_performance_score(metrics) do
    # Simple performance score based on response times and error rates
    base_score = 100
    
    # Penalize slow response times (>100ms)
    time_penalty = if metrics.avg_request_time > 100, do: 10, else: 0
    
    # Penalize high error rates
    error_penalty = min(metrics.error_count, 20)
    
    max(base_score - time_penalty - error_penalty, 0)
  end
end