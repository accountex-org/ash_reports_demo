# Phase 4: Streaming Reports & Real-time Features

**Duration**: 2-3 weeks
**Goal**: Add streaming report support with progress tracking and WebSocket updates
**Prerequisites**: Phase 1, 2, and 3 completed

---

## Overview

Phase 4 implements streaming report execution for large datasets (10K+ records) with real-time progress tracking via WebSocket channels. This phase leverages the AshReports GenStage streaming pipeline to provide memory-efficient processing with live UI updates.

**Key Deliverable**: Streaming reports with real-time progress bars, pause/resume/cancel capabilities, and performance monitoring dashboard.

---

## Section 4.1: Streaming Infrastructure

### 4.1.1 Streaming Report Runner

**File**: `lib/ash_reports_demo_web/reports/streaming_runner.ex`
**Estimated Lines**: ~200

#### Purpose
Manage streaming pipeline execution with progress tracking and control operations.

#### Tasks
- [ ] Create `StreamingRunner` module
  ```elixir
  defmodule AshReportsDemoWeb.Reports.StreamingRunner do
    use GenServer

    def start_stream(report_name, params, opts \\ [])
    def cancel_stream(stream_id)
    def pause_stream(stream_id)
    def resume_stream(stream_id)
    def get_stream_status(stream_id)
  end
  ```

- [ ] Use `AshReports.Runner.run_report/4` with `streaming: true`
  ```elixir
  def start_stream(report_name, params, opts) do
    stream_opts = [
      format: Keyword.get(opts, :format, :html),
      streaming: true,
      chunk_size: Keyword.get(opts, :chunk_size, 1000),
      progress_callback: &handle_progress/1
    ]

    case AshReports.Runner.run_report(
      AshReportsDemo.Domain,
      report_name,
      params,
      stream_opts
    ) do
      {:ok, stream} ->
        stream_id = generate_stream_id()
        {:ok, pid} = start_stream_consumer(stream_id, stream, opts)
        {:ok, stream_id, pid}

      error ->
        error
    end
  end
  ```

- [ ] Manage streaming pipelines
  - Track active streams in ETS
  - Associate streams with user sessions
  - Cleanup on disconnect
  - Resource limits (max concurrent)

- [ ] Track progress via GenStage events
  ```elixir
  defp handle_progress(progress_event) do
    %{
      stream_id: stream_id,
      stage: stage,
      records_processed: records_processed,
      total_estimate: total_estimate,
      throughput: throughput
    } = progress_event

    # Broadcast via Phoenix.PubSub
    Phoenix.PubSub.broadcast(
      AshReportsDemo.PubSub,
      "stream:#{stream_id}",
      {:progress_update, progress_event}
    )
  end
  ```

- [ ] Handle cancellation requests
  ```elixir
  def cancel_stream(stream_id) do
    case Registry.lookup(StreamRegistry, stream_id) do
      [{pid, _}] ->
        GenServer.call(pid, :cancel)
        cleanup_stream(stream_id)
        :ok

      [] ->
        {:error, :stream_not_found}
    end
  end
  ```

- [ ] Memory monitoring during streaming
  - Track process memory usage
  - Alert on threshold exceeded
  - Auto-pause on memory pressure
  - Graceful degradation

- [ ] Chunk result assembly
  ```elixir
  defp assemble_chunks(chunks, format) do
    case format do
      :html -> concatenate_html_chunks(chunks)
      :json -> merge_json_chunks(chunks)
      :pdf -> merge_pdf_chunks(chunks)
      _ -> Enum.join(chunks, "\n")
    end
  end
  ```

---

### 4.1.2 Progress Tracking System

**File**: `lib/ash_reports_demo_web/reports/progress_tracker.ex`
**Estimated Lines**: ~150

#### Purpose
GenServer for managing progress state and calculations.

#### Tasks
- [ ] Create `ProgressTracker` GenServer
  ```elixir
  defmodule AshReportsDemoWeb.Reports.ProgressTracker do
    use GenServer

    def start_link(opts)
    def init_progress(stream_id, total_estimate)
    def update_progress(stream_id, records_processed)
    def get_progress(stream_id)
    def complete(stream_id)
  end
  ```

- [ ] GenServer for progress state management
  ```elixir
  def init(_) do
    {:ok, %{
      streams: %{},
      start_times: %{}
    }}
  end

  def handle_call({:init_progress, stream_id, total}, _from, state) do
    progress = %{
      total_estimate: total,
      records_processed: 0,
      percent_complete: 0,
      started_at: DateTime.utc_now(),
      stage: :initializing
    }

    updated_state = put_in(state, [:streams, stream_id], progress)
    {:reply, :ok, updated_state}
  end
  ```

- [ ] Track records processed / total estimate
  ```elixir
  def handle_cast({:update, stream_id, records_processed}, state) do
    case get_in(state, [:streams, stream_id]) do
      nil ->
        {:noreply, state}

      progress ->
        updated_progress = %{progress |
          records_processed: records_processed,
          percent_complete: calculate_percent(
            records_processed,
            progress.total_estimate
          )
        }

        updated_state = put_in(state, [:streams, stream_id], updated_progress)
        broadcast_progress(stream_id, updated_progress)
        {:noreply, updated_state}
    end
  end
  ```

- [ ] Stage progress tracking (data loading, rendering, etc.)
  ```elixir
  @stages [:initializing, :data_loading, :processing, :rendering, :finalizing, :complete]

  defp update_stage(progress, new_stage) do
    %{progress |
      stage: new_stage,
      stage_index: Enum.find_index(@stages, &(&1 == new_stage))
    }
  end
  ```

- [ ] WebSocket broadcast support
  ```elixir
  defp broadcast_progress(stream_id, progress) do
    Phoenix.PubSub.broadcast(
      AshReportsDemo.PubSub,
      "stream:#{stream_id}",
      {:progress_update, progress}
    )
  end
  ```

- [ ] Progress persistence for page refreshes
  - Store in ETS with TTL
  - Reload on reconnect
  - Handle stale progress

- [ ] ETA calculation based on throughput
  ```elixir
  defp calculate_eta(progress) do
    elapsed = DateTime.diff(DateTime.utc_now(), progress.started_at)
    remaining = progress.total_estimate - progress.records_processed

    if progress.records_processed > 0 do
      throughput = progress.records_processed / elapsed
      remaining / throughput
    else
      nil
    end
  end
  ```

---

### 4.1.3 WebSocket Progress Channel

**File**: `lib/ash_reports_demo_web/channels/report_channel.ex`
**Estimated Lines**: ~120

#### Purpose
Phoenix Channel for real-time progress updates to the browser.

#### Tasks
- [ ] Create `ReportChannel` Phoenix Channel
  ```elixir
  defmodule AshReportsDemoWeb.ReportChannel do
    use Phoenix.Channel

    def join("report:" <> stream_id, _payload, socket) do
      if authorized?(socket, stream_id) do
        {:ok, assign(socket, :stream_id, stream_id)}
      else
        {:error, %{reason: "unauthorized"}}
      end
    end

    def handle_in("cancel", _payload, socket) do
      StreamingRunner.cancel_stream(socket.assigns.stream_id)
      {:reply, :ok, socket}
    end
  end
  ```

- [ ] Subscribe to report generation events
  ```elixir
  def handle_info({:progress_update, progress}, socket) do
    push(socket, "progress", progress)
    {:noreply, socket}
  end

  def handle_info({:stream_complete, result}, socket) do
    push(socket, "complete", %{result: result})
    {:noreply, socket}
  end
  ```

- [ ] Broadcast progress updates
  - Every N records (configurable)
  - Stage transitions
  - Error events
  - Completion events

- [ ] Send completion notifications
  ```elixir
  defp notify_completion(stream_id, result) do
    Phoenix.PubSub.broadcast(
      AshReportsDemo.PubSub,
      "stream:#{stream_id}",
      {:stream_complete, result}
    )
  end
  ```

- [ ] Error notifications
  ```elixir
  defp notify_error(stream_id, error) do
    Phoenix.PubSub.broadcast(
      AshReportsDemo.PubSub,
      "stream:#{stream_id}",
      {:stream_error, error}
    )
  end
  ```

- [ ] Cancellation support
  ```elixir
  def handle_in("cancel", _payload, socket) do
    stream_id = socket.assigns.stream_id

    case StreamingRunner.cancel_stream(stream_id) do
      :ok -> {:reply, {:ok, %{message: "Stream cancelled"}}, socket}
      error -> {:reply, error, socket}
    end
  end
  ```

---

## Section 4.2: Streaming UI Components

### 4.2.1 Progress Bar Component

**File**: `lib/ash_reports_demo_web/components/report_progress.ex`
**Estimated Lines**: ~150

#### Purpose
Animated progress bar with detailed status information.

#### Tasks
- [ ] Create `ReportProgress` LiveComponent
  ```elixir
  defmodule AshReportsDemoWeb.Components.ReportProgress do
    use Phoenix.LiveComponent

    def mount(socket) do
      {:ok, assign(socket, progress: nil, connected: false)}
    end

    def update(assigns, socket) do
      if assigns.stream_id && !socket.assigns.connected do
        :ok = Phoenix.PubSub.subscribe(
          AshReportsDemo.PubSub,
          "stream:#{assigns.stream_id}"
        )
        {:ok, assign(socket, assigns) |> assign(connected: true)}
      else
        {:ok, assign(socket, assigns)}
      end
    end

    def handle_info({:progress_update, progress}, socket) do
      {:noreply, assign(socket, progress: progress)}
    end
  end
  ```

- [ ] Animated progress bar
  ```heex
  <div class="progress-container">
    <div class="progress-bar">
      <div
        class="progress-fill"
        style={"width: #{@progress.percent_complete}%"}
      >
        <span class="progress-text">
          <%= @progress.percent_complete %>%
        </span>
      </div>
    </div>
  </div>
  ```

- [ ] Stage indicators
  ```heex
  <div class="stage-indicators">
    <div
      :for={{stage, index} <- Enum.with_index(@stages)}
      class={stage_class(stage, @progress)}
    >
      <.icon name={stage_icon(stage)} />
      <%= humanize(stage) %>
    </div>
  </div>
  ```

- [ ] Records processed counter
  ```heex
  <div class="progress-stats">
    <span class="stat">
      <strong><%= @progress.records_processed %></strong>
      of
      <strong><%= @progress.total_estimate %></strong>
      records processed
    </span>
  </div>
  ```

- [ ] Estimated time remaining
  ```heex
  <div class="eta" :if={@progress.eta}>
    <.icon name="hero-clock" />
    Estimated time: <%= format_duration(@progress.eta) %>
  </div>
  ```

- [ ] Memory usage indicator
  ```heex
  <div class="memory-usage" :if={@progress.memory_mb}>
    <div class="memory-bar">
      <div
        class="memory-fill"
        style={"width: #{memory_percent(@progress)}%"}
      />
    </div>
    <span><%= @progress.memory_mb %> MB</span>
  </div>
  ```

- [ ] Cancel button with confirmation
  ```heex
  <button
    phx-click="cancel_stream"
    phx-target={@myself}
    data-confirm="Cancel report generation?"
    class="btn-cancel"
  >
    <.icon name="hero-x-mark" />
    Cancel
  </button>
  ```

---

### 4.2.2 Streaming Report Viewer

**File**: `lib/ash_reports_demo_web/live/report_live/streaming.ex`
**Estimated Lines**: ~280

#### Purpose
LiveView for displaying streaming reports with progressive content display.

#### Tasks
- [ ] Create `ReportLive.Streaming` LiveView
  ```elixir
  defmodule AshReportsDemoWeb.ReportLive.Streaming do
    use AshReportsDemoWeb, :live_view

    alias AshReportsDemoWeb.Reports.StreamingRunner

    def mount(%{"name" => report_name}, _session, socket) do
      {:ok, initialize_streaming_view(socket, report_name)}
    end

    def handle_event("start_stream", params, socket) do
      case StreamingRunner.start_stream(
        socket.assigns.report_name,
        params,
        progress_pid: self()
      ) do
        {:ok, stream_id, _pid} ->
          {:noreply, assign(socket, stream_id: stream_id, streaming: true)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, format_error(reason))}
      end
    end
  end
  ```

- [ ] LiveView for streaming reports
  - Subscribe to stream channel
  - Display progress component
  - Show partial results
  - Handle completion

- [ ] Progressive content display as chunks arrive
  ```heex
  <div class="streaming-report">
    <.live_component
      module={ReportProgress}
      id="progress"
      stream_id={@stream_id}
    />

    <div class="content-chunks">
      <div :for={chunk <- @chunks} class="chunk">
        <%= raw(chunk) %>
      </div>
    </div>
  </div>
  ```

- [ ] Real-time statistics updates
  ```elixir
  def handle_info({:progress_update, progress}, socket) do
    stats = calculate_streaming_stats(progress)

    {:noreply,
     socket
     |> assign(progress: progress)
     |> assign(stats: stats)
     |> maybe_add_chunk(progress)}
  end
  ```

- [ ] Pause/resume functionality
  ```elixir
  def handle_event("pause_stream", _, socket) do
    :ok = StreamingRunner.pause_stream(socket.assigns.stream_id)
    {:noreply, assign(socket, paused: true)}
  end

  def handle_event("resume_stream", _, socket) do
    :ok = StreamingRunner.resume_stream(socket.assigns.stream_id)
    {:noreply, assign(socket, paused: false)}
  end
  ```

- [ ] Auto-scroll to new content
  ```javascript
  // Phoenix hook for auto-scroll
  Hooks.AutoScroll = {
    updated() {
      if (this.el.dataset.autoScroll === "true") {
        this.el.scrollIntoView({ behavior: "smooth", block: "end" });
      }
    }
  };
  ```

---

### 4.2.3 Report Queue Component

**File**: `lib/ash_reports_demo_web/components/report_queue.ex`
**Estimated Lines**: ~200

#### Purpose
Display and manage multiple concurrent report generation jobs.

#### Tasks
- [ ] Create `ReportQueue` LiveComponent
  ```elixir
  defmodule AshReportsDemoWeb.Components.ReportQueue do
    use Phoenix.LiveComponent

    def mount(socket) do
      :ok = Phoenix.PubSub.subscribe(AshReportsDemo.PubSub, "queue:updates")
      {:ok, load_queue_state(socket)}
    end
  end
  ```

- [ ] Display list of running reports
  ```heex
  <div class="report-queue">
    <h3>Report Queue</h3>

    <div class="queue-stats">
      <span>Running: <%= length(@running) %></span>
      <span>Queued: <%= length(@queued) %></span>
      <span>Completed: <%= length(@completed) %></span>
    </div>

    <div class="queue-items">
      <div :for={job <- @running} class="queue-item running">
        <div class="job-info">
          <strong><%= job.report_name %></strong>
          <span class="job-user"><%= job.user %></span>
        </div>
        <.report_progress stream_id={job.stream_id} />
        <button phx-click="cancel_job" phx-value-id={job.id}>
          Cancel
        </button>
      </div>
    </div>
  </div>
  ```

- [ ] Progress for each report
  - Mini progress bars
  - ETA display
  - Stage indicators

- [ ] Cancel individual reports
  ```elixir
  def handle_event("cancel_job", %{"id" => job_id}, socket) do
    case find_job(socket.assigns.running, job_id) do
      nil ->
        {:noreply, socket}

      job ->
        :ok = StreamingRunner.cancel_stream(job.stream_id)
        {:noreply, remove_job(socket, job_id)}
    end
  end
  ```

- [ ] View completed reports
  ```heex
  <div class="completed-reports">
    <h4>Recently Completed</h4>
    <div :for={report <- @completed} class="completed-item">
      <span><%= report.report_name %></span>
      <span class="completion-time">
        <%= format_relative_time(report.completed_at) %>
      </span>
      <.link navigate={view_report_path(report)}>
        View
      </.link>
    </div>
  </div>
  ```

- [ ] Clear completed reports
  ```elixir
  def handle_event("clear_completed", _, socket) do
    {:noreply, assign(socket, completed: [])}
  end
  ```

- [ ] Queue statistics
  - Total reports generated
  - Average execution time
  - Success/failure rate
  - Current load

---

## Section 4.3: Performance Monitoring

### 4.3.1 Performance Dashboard

**File**: `lib/ash_reports_demo_web/live/dashboard_live/performance.ex`
**Estimated Lines**: ~230

#### Purpose
Real-time metrics display for system performance monitoring.

#### Tasks
- [ ] Create `DashboardLive.Performance` LiveView
  ```elixir
  defmodule AshReportsDemoWeb.DashboardLive.Performance do
    use AshReportsDemoWeb, :live_view

    def mount(_params, _session, socket) do
      if connected?(socket) do
        :timer.send_interval(1000, self(), :update_metrics)
      end

      {:ok, load_performance_metrics(socket)}
    end

    def handle_info(:update_metrics, socket) do
      {:noreply, update_metrics(socket)}
    end
  end
  ```

- [ ] Real-time metrics display
  ```heex
  <div class="performance-dashboard">
    <div class="metric-cards">
      <div class="metric-card">
        <h4>Active Streams</h4>
        <div class="metric-value"><%= @metrics.active_streams %></div>
      </div>

      <div class="metric-card">
        <h4>Avg Execution Time</h4>
        <div class="metric-value">
          <%= format_duration(@metrics.avg_execution_time) %>
        </div>
      </div>

      <!-- More metrics -->
    </div>
  </div>
  ```

- [ ] Report execution times
  - Histogram of execution times
  - P50, P95, P99 percentiles
  - Trend over time
  - Breakdown by report type

- [ ] Cache hit rates
  - Overall hit rate
  - Per-report hit rates
  - Cache size and memory usage
  - Eviction statistics

- [ ] Memory usage graphs
  ```heex
  <div class="memory-chart">
    <.chart_viewer
      chart_type={:line}
      data={@memory_history}
      config={%{
        title: "Memory Usage Over Time",
        width: 800,
        height: 300
      }}
    />
  </div>
  ```

- [ ] Pipeline stage timings
  - Time spent in each stage
  - Bottleneck identification
  - Stage-specific metrics

- [ ] Error rates and types
  - Error count by type
  - Error percentage
  - Recent errors list
  - Error trends

---

### 4.3.2 Telemetry Integration

**File**: `lib/ash_reports_demo/telemetry.ex`
**Estimated Lines**: ~150

#### Purpose
Integrate with AshReports telemetry events for metrics collection.

#### Tasks
- [ ] Create `AshReportsDemo.Telemetry` module
  ```elixir
  defmodule AshReportsDemo.Telemetry do
    use Supervisor

    def start_link(arg) do
      Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
    end

    def init(_arg) do
      children = [
        {:telemetry_poller, measurements: periodic_measurements(), period: 1_000}
      ]

      Supervisor.init(children, strategy: :one_for_one)
    end
  end
  ```

- [ ] Attach to AshReports telemetry events
  ```elixir
  def attach_handlers do
    events = [
      [:ash_reports, :runner, :run_report, :start],
      [:ash_reports, :runner, :run_report, :stop],
      [:ash_reports, :runner, :run_report, :exception],
      [:ash_reports, :charts, :generate, :start],
      [:ash_reports, :charts, :generate, :stop]
    ]

    :telemetry.attach_many(
      "ash-reports-demo-handler",
      events,
      &handle_event/4,
      nil
    )
  end
  ```

- [ ] Aggregate metrics for dashboard
  ```elixir
  defp handle_event([:ash_reports, :runner, :run_report, :stop], measurements, metadata, _config) do
    duration = measurements.duration
    report_name = metadata.report_name

    Metrics.update_report_duration(report_name, duration)
    Metrics.increment_report_count(report_name)

    if measurements.cache_hit do
      Metrics.increment_cache_hits(report_name)
    end
  end
  ```

- [ ] Store historical data (last 24 hours)
  - ETS table for recent data
  - Circular buffer for memory efficiency
  - Configurable retention period

- [ ] Publish metrics via Phoenix.LiveDashboard
  - Custom LiveDashboard page
  - Real-time metric updates
  - Historical charts

- [ ] Alert thresholds for anomalies
  - High error rates
  - Slow execution times
  - Memory pressure
  - Queue depth

---

## Deliverables

### Code Deliverables
- [ ] `StreamingRunner` GenServer - Stream management
- [ ] `ProgressTracker` GenServer - Progress tracking
- [ ] `ReportChannel` - WebSocket communication
- [ ] `ReportProgress` component - Progress bar UI
- [ ] `ReportLive.Streaming` - Streaming viewer
- [ ] `ReportQueue` component - Job queue display
- [ ] `DashboardLive.Performance` - Metrics dashboard
- [ ] `Telemetry` module - Metrics collection

### Documentation
- [ ] Streaming report guide
- [ ] WebSocket integration guide
- [ ] Performance monitoring guide
- [ ] Telemetry events reference

### Success Metrics
- [ ] Streaming works for 10K+ record reports
- [ ] Memory usage stays below 1.5x baseline
- [ ] Progress updates arrive within 100ms
- [ ] Pause/resume/cancel work reliably
- [ ] Dashboard updates in real-time

---

## Testing Requirements

### Unit Tests
- [ ] StreamingRunner tests
- [ ] ProgressTracker tests
- [ ] Progress calculation tests

### Integration Tests
- [ ] End-to-end streaming report
- [ ] WebSocket communication
- [ ] Cancel/pause/resume operations
- [ ] Progress accuracy

### Performance Tests
- [ ] Large dataset streaming (100K records)
- [ ] Memory usage validation
- [ ] Throughput measurement
- [ ] Concurrent stream handling

---

## Dependencies

### External Dependencies
- Phoenix.PubSub (already available)
- Phoenix.Channel (already available)

### Internal Dependencies
- Phase 1: PipelineClient
- AshReports GenStage pipeline

---

## Next Phase

After Phase 4 completion, proceed to:
- **Phase 5**: Advanced Features & Polish
  - Report management features
  - UI enhancements
  - Dark mode and responsive design
