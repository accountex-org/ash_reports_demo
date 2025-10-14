# Phase 1: Core Pipeline Integration

**Duration**: 1-2 weeks
**Goal**: Replace existing LiveView components with pipeline-aware implementations

---

## Overview

Phase 1 establishes the foundation for the entire UI modernization by replacing direct Ash.read queries with the full AshReports pipeline architecture. This phase creates reusable modules for pipeline interaction, error handling, and result processing that will be used throughout all subsequent phases.

**Key Deliverable**: A working report viewer that executes reports through the complete three-stage pipeline (DataLoader → RenderContext → RenderPipeline).

---

## Section 1.1: Report Execution Foundation

### 1.1.1 Pipeline Integration Module

**File**: `lib/ash_reports_demo_web/reports/pipeline_client.ex`
**Estimated Lines**: ~150

#### Purpose
Client wrapper for `AshReports.Runner` that provides a clean API for LiveView components to execute reports through the full pipeline.

#### Tasks
- [ ] Create `PipelineClient` module with public API functions
  - `run_report/3` - Execute report with parameters and format
  - `run_report_async/3` - Execute report in background task
  - `validate_parameters/2` - Validate parameters before execution
  - `get_report_info/2` - Get report metadata from domain

- [ ] Implement format selection and validation
  ```elixir
  @valid_formats [:html, :pdf, :json, :heex]

  def run_report(domain, report_name, params, opts \\ []) do
    format = Keyword.get(opts, :format, :html)

    with :ok <- validate_format(format),
         :ok <- validate_parameters(domain, report_name, params),
         {:ok, result} <- execute_pipeline(domain, report_name, params, format) do
      {:ok, normalize_result(result, format)}
    end
  end
  ```

- [ ] Add progress tracking callbacks for streaming reports
  ```elixir
  def run_report_with_progress(domain, report_name, params, callback_pid) do
    opts = [
      streaming: true,
      progress_callback: fn progress ->
        send(callback_pid, {:progress, progress})
      end
    ]

    AshReports.Runner.run_report(domain, report_name, params, opts)
  end
  ```

- [ ] Implement timeout and cancellation support
  - Default timeout: 30 seconds
  - Configurable per report
  - Task cancellation on timeout

- [ ] Add result parsing and normalization
  - Extract content, metadata, format from pipeline result
  - Parse error structures with stage context
  - Normalize different format outputs

#### Dependencies
- `AshReports.Runner`
- `AshReports.Info` (for report metadata)

---

### 1.1.2 Report Result Handling

**File**: `lib/ash_reports_demo_web/reports/result_handler.ex`
**Estimated Lines**: ~100

#### Purpose
Process and transform pipeline results for display in the UI, including metadata extraction and error formatting.

#### Tasks
- [ ] Create `ResultHandler` module with result processing functions
  - `process/1` - Main result processing function
  - `extract_metadata/1` - Extract pipeline metadata
  - `format_for_display/2` - Format content for specific display type
  - `get_execution_summary/1` - Create human-readable summary

- [ ] Parse pipeline metadata
  ```elixir
  def extract_metadata(result) do
    %{
      execution_time: result.metadata.execution_time_ms,
      record_count: result.metadata.record_count,
      stages_executed: result.metadata.stages_executed || [],
      pipeline_version: result.metadata.pipeline_version,
      format: result.format
    }
  end
  ```

- [ ] Extract error information with stage context
  ```elixir
  def parse_error({:error, %{stage: stage, reason: reason}}) do
    %{
      stage: stage,
      reason: reason,
      user_message: stage_error_message(stage, reason),
      suggested_action: suggest_action_for_stage(stage)
    }
  end
  ```

- [ ] Format result content for display
  - HTML: Return as-is with proper escaping
  - PDF: Generate download metadata
  - JSON: Pretty-print for display
  - HEEX: Prepare for component rendering

- [ ] Handle different output formats
  - Size calculation for downloads
  - MIME type detection
  - Filename generation

- [ ] Cache result metadata for UI display
  - Store in process state or ETS
  - TTL management
  - Cache invalidation

#### Output Format
```elixir
%{
  content: "...",  # Format-specific content
  metadata: %{
    execution_time_ms: 1234,
    record_count: 500,
    stages: [:data_loading, :context_building, :rendering],
    format: :html,
    size_bytes: 45000
  },
  display: %{
    title: "Customer Summary Report",
    subtitle: "Generated at 2025-10-14 10:30:00",
    summary: "500 records processed in 1.2 seconds"
  }
}
```

---

### 1.1.3 Error Display Component

**File**: `lib/ash_reports_demo_web/components/report_error.ex`
**Estimated Lines**: ~80

#### Purpose
Reusable LiveView component for displaying pipeline errors with stage context and suggested actions.

#### Tasks
- [ ] Create `ReportError` functional component
  ```elixir
  defmodule AshReportsDemoWeb.Components.ReportError do
    use Phoenix.Component

    attr :error, :map, required: true
    attr :retry_callback, :any, default: nil

    def report_error(assigns) do
      ~H"""
      <div class="error-container">
        <div class="error-header">
          <h3>Report Generation Failed</h3>
          <span class="error-stage"><%= @error.stage %></span>
        </div>
        <!-- Error details -->
      </div>
      """
    end
  end
  ```

- [ ] Stage-based error visualization
  - Visual pipeline diagram showing failure point
  - Color-coded stages (completed, failed, not executed)
  - Error details expansion

- [ ] Friendly error messages with suggested actions
  ```elixir
  defp stage_error_message(:data_loading, reason) do
    "Failed to load data: #{format_reason(reason)}. " <>
    "Check that the report exists and parameters are valid."
  end

  defp stage_error_message(:rendering, reason) do
    "Failed to render report: #{format_reason(reason)}. " <>
    "The data loaded successfully but rendering failed."
  end
  ```

- [ ] Retry mechanisms for failed reports
  - Retry button with loading state
  - Exponential backoff for automatic retries
  - Retry count limit

- [ ] Error details expansion/collapse
  - Show/hide technical details
  - Stack trace (in dev mode)
  - Full error object (JSON)

- [ ] Integration with pipeline error structure
  - Handle all error formats from pipeline
  - Graceful degradation for unknown errors
  - Telemetry event emission

#### Component Usage
```heex
<.report_error
  error={@error_data}
  retry_callback={fn -> send(self(), :retry_report) end}
/>
```

---

## Section 1.2: LiveView Report Components Replacement

### 1.2.1 Report Index Page Modernization

**File**: `lib/ash_reports_demo_web/live/report_live/index.ex` (MODIFY EXISTING)
**Estimated Changes**: ~100 lines added/modified

#### Purpose
Update the main report listing page to display report metadata from AshReports.Info and provide format selection.

#### Tasks
- [ ] Replace hardcoded report list with `AshReports.Info.reports/1`
  ```elixir
  def mount(_params, _session, socket) do
    reports = AshReports.Info.reports(AshReportsDemo.Domain)

    enriched_reports = Enum.map(reports, &enrich_report_metadata/1)

    {:ok, assign(socket, reports: enriched_reports)}
  end
  ```

- [ ] Display report metadata
  - Report name and description
  - Parameter count and types
  - Variable definitions
  - Band structure
  - Group hierarchy

- [ ] Add format selection UI
  ```heex
  <div class="format-selector">
    <label>Output Format:</label>
    <select name="format" phx-change="format_changed">
      <option value="html">HTML</option>
      <option value="pdf">PDF</option>
      <option value="json">JSON</option>
    </select>
  </div>
  ```

- [ ] Show report complexity indicators
  - Record count estimates
  - Processing time estimates
  - Memory usage estimates
  - Streaming recommended badge

- [ ] Add "Quick Run" buttons with default parameters
  - One-click report execution
  - Use default parameter values
  - Navigate to viewer on success

- [ ] Implement report search and filtering
  - Filter by category (if defined)
  - Search by name/description
  - Filter by complexity

#### New Template Structure
```heex
<div class="report-library">
  <header>
    <h1>Available Reports</h1>
    <input type="search" placeholder="Search reports..." />
  </header>

  <div class="report-grid">
    <div :for={report <- @reports} class="report-card">
      <h3><%= report.title %></h3>
      <p><%= report.description %></p>

      <div class="report-meta">
        <span><%= length(report.parameters) %> parameters</span>
        <span><%= length(report.variables) %> variables</span>
      </div>

      <.link navigate={~p"/reports/#{report.name}"}>
        View Report →
      </.link>
    </div>
  </div>
</div>
```

---

### 1.2.2 Simple Report Viewer Replacement

**File**: `lib/ash_reports_demo_web/live/report_live/simple.ex` (REMOVE)

#### Purpose
This file will be removed and replaced by the new universal report viewer (Section 1.2.3).

#### Tasks
- [ ] Mark file for deletion
- [ ] Document migration path for any custom logic
- [ ] Update router to point to new viewer

---

### 1.2.3 New Report Viewer Component

**File**: `lib/ash_reports_demo_web/live/report_live/viewer.ex` (CREATE NEW)
**Estimated Lines**: ~230

#### Purpose
Universal report viewer that works with all report types and formats through the pipeline.

#### Tasks
- [ ] Create new `ReportLive.Viewer` LiveView module
  ```elixir
  defmodule AshReportsDemoWeb.ReportLive.Viewer do
    use AshReportsDemoWeb, :live_view

    alias AshReportsDemoWeb.Reports.PipelineClient

    def mount(%{"name" => report_name}, _session, socket) do
      {:ok, initialize_viewer(socket, report_name)}
    end
  end
  ```

- [ ] Unified interface for all report formats
  - Single LiveView handles all reports
  - Dynamic UI based on report definition
  - Format-agnostic display logic

- [ ] Parameter input forms with validation
  - Dynamic form generation from report parameters
  - Type-specific input widgets
  - Real-time validation
  - Error display

- [ ] Format selection dropdown
  ```heex
  <.format_selector
    current_format={@format}
    on_change={&send(self(), {:format_changed, &1})}
  />
  ```

- [ ] Execute button with loading states
  - Disabled during execution
  - Loading spinner
  - Progress indication
  - Cancel button (for streaming)

- [ ] Result display area with format-specific rendering
  ```heex
  <%= case @result_state do %>
    <% :idle -> %>
      <div class="placeholder">
        Click "Run Report" to generate
      </div>

    <% :loading -> %>
      <div class="loading">
        <.spinner />
        Generating report...
      </div>

    <% :success -> %>
      <.render_result
        result={@result}
        format={@format}
      />

    <% :error -> %>
      <.report_error error={@error} />
  <% end %>
  ```

- [ ] Error display with retry options
  - Use ReportError component
  - Retry button
  - Edit parameters option
  - Switch format option

- [ ] Handle live updates from streaming reports
  - Subscribe to progress events
  - Update UI as chunks arrive
  - Display partial results
  - Show completion status

#### LiveView State
```elixir
%{
  report_name: :customer_summary,
  report_definition: %{...},
  parameters: %{region: "CA"},
  format: :html,
  result_state: :idle | :loading | :success | :error,
  result: nil,
  error: nil,
  execution_metadata: %{}
}
```

---

### 1.2.4 Report Parameter Forms

**File**: `lib/ash_reports_demo_web/components/parameter_form.ex` (CREATE NEW)
**Estimated Lines**: ~180

#### Purpose
Dynamic form component that generates input fields from report parameter definitions.

#### Tasks
- [ ] Create `ParameterForm` functional component
  ```elixir
  defmodule AshReportsDemoWeb.Components.ParameterForm do
    use Phoenix.Component

    attr :parameters, :list, required: true
    attr :values, :map, default: %{}
    attr :on_change, :any, required: true

    def parameter_form(assigns)
  end
  ```

- [ ] Auto-generate forms from report parameter definitions
  ```elixir
  def render_parameter_field(%{type: :string} = param, value) do
    ~H"""
    <input type="text"
           name={@param.name}
           value={@value}
           phx-change="param_changed" />
    """
  end
  ```

- [ ] Type-specific input widgets
  - `:string` → text input
  - `:integer` → number input
  - `:date` → date picker
  - `:atom` with constraints → dropdown/radio
  - `:boolean` → checkbox
  - `:decimal` → number input with decimal

- [ ] Validation with inline error messages
  ```elixir
  def validate_parameter(param, value) do
    with :ok <- validate_type(param.type, value),
         :ok <- validate_constraints(param.constraints, value) do
      :ok
    else
      {:error, reason} -> {:error, format_validation_error(reason)}
    end
  end
  ```

- [ ] Default value support
  - Pre-populate with defaults
  - Show default in placeholder
  - Reset to default button

- [ ] Required/optional field handling
  - Visual indicators (asterisks)
  - Validation on submit
  - Disable submit if required fields empty

#### Component Usage
```heex
<.parameter_form
  parameters={@report.parameters}
  values={@parameter_values}
  on_change={fn params -> send(self(), {:params_updated, params}) end}
/>
```

---

## Section 1.3: Testing Infrastructure

### 1.3.1 Component Tests

**File**: `test/ash_reports_demo_web/live/report_live/viewer_test.exs`
**Estimated Lines**: ~150

#### Tasks
- [ ] Test report loading with different formats
  ```elixir
  test "loads report with HTML format", %{conn: conn} do
    {:ok, view, html} = live(conn, "/reports/customer_summary?format=html")

    assert html =~ "Customer Summary Report"
    assert has_element?(view, "select[name=format]")
  end
  ```

- [ ] Test parameter validation
  - Valid parameters accepted
  - Invalid parameters rejected
  - Validation errors displayed

- [ ] Test error display
  - Pipeline errors shown correctly
  - Stage context displayed
  - Retry button functional

- [ ] Test format switching
  - Format changes update UI
  - Format persists across loads
  - Invalid formats rejected

---

**File**: `test/ash_reports_demo_web/components/parameter_form_test.exs`
**Estimated Lines**: ~100

#### Tasks
- [ ] Test form generation from parameters
  - All parameter types rendered
  - Default values populated
  - Labels and descriptions shown

- [ ] Test validation logic
  - Type validation works
  - Constraint validation works
  - Error messages clear

- [ ] Test submission handling
  - Valid submission succeeds
  - Invalid submission blocked
  - Values properly encoded

---

### 1.3.2 Integration Tests

**File**: `test/ash_reports_demo_web/integration/pipeline_integration_test.exs`
**Estimated Lines**: ~200

#### Tasks
- [ ] End-to-end report execution
  ```elixir
  test "executes customer summary report through pipeline" do
    {:ok, result} = PipelineClient.run_report(
      AshReportsDemo.Domain,
      :customer_summary,
      %{region: "CA"},
      format: :html
    )

    assert result.format == :html
    assert result.metadata.record_count > 0
    assert String.contains?(result.content, "Customer Summary")
  end
  ```

- [ ] Test all 4 existing reports
  - `:customer_summary`
  - `:product_inventory`
  - `:invoice_details`
  - `:financial_summary`

- [ ] Test all output formats
  - HTML content generation
  - PDF binary generation
  - JSON structure validation
  - HEEX component rendering

- [ ] Test error scenarios
  - Invalid report name
  - Invalid parameters
  - Query failures
  - Renderer failures

---

## Deliverables

### Code Deliverables
- [ ] `PipelineClient` module - Pipeline interaction wrapper
- [ ] `ResultHandler` module - Result processing utilities
- [ ] `ReportError` component - Error display component
- [ ] `ReportLive.Viewer` - Universal report viewer LiveView
- [ ] `ParameterForm` component - Dynamic parameter forms
- [ ] Updated `ReportLive.Index` - Report listing page
- [ ] Test suite - 3 test files with comprehensive coverage

### Documentation
- [ ] Module documentation for all new modules
- [ ] Function documentation with examples
- [ ] Integration guide for other phases
- [ ] Migration guide from old components

### Success Metrics
- [ ] All 4 existing reports work through pipeline
- [ ] All tests passing (target: 100% for new code)
- [ ] No compilation warnings
- [ ] Response time <2s for small reports
- [ ] Memory usage comparable to direct queries

---

## Dependencies

### External Dependencies
- AshReports library (already available)
- Phoenix.LiveView
- Phoenix.Component

### Internal Dependencies
- AshReportsDemo.Domain (existing)
- Data generation system (existing, unchanged)

---

## Next Phase

After Phase 1 completion, proceed to:
- **Phase 2**: Multi-Format Output Support
  - Builds on pipeline integration
  - Adds format-specific handlers
  - Implements download capabilities
