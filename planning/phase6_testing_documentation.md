# Phase 6: Testing & Documentation

**Duration**: 1 week
**Goal**: Comprehensive testing and documentation
**Prerequisites**: All previous phases completed

---

## Overview

Phase 6 finalizes the project with comprehensive testing, performance validation, and complete documentation. This phase ensures production readiness through extensive test coverage, performance benchmarking, and user/developer documentation.

**Key Deliverable**: Production-ready application with 80%+ test coverage and complete documentation.

---

## Section 6.1: Testing Suite

### 6.1.1 LiveView Tests

**Files**: Multiple test files in `test/ash_reports_demo_web/live/`
**Estimated Lines**: ~800 total

#### Purpose
Comprehensive tests for all LiveView modules.

#### Tasks

**Report Viewer Tests** (`test/ash_reports_demo_web/live/report_live/viewer_test.exs`)
- [ ] Test report loading with different formats
  ```elixir
  describe "report loading" do
    test "loads customer_summary report with HTML format", %{conn: conn} do
      {:ok, view, html} = live(conn, "/reports/customer_summary?format=html")

      assert html =~ "Customer Summary Report"
      assert has_element?(view, "select[name=format]")
    end

    test "loads report with PDF format", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/customer_summary?format=pdf")

      assert view
             |> element("button[phx-click=download_pdf]")
             |> has_element?()
    end
  end
  ```

- [ ] Test parameter validation
  - Valid parameters accepted and report runs
  - Invalid parameters show error messages
  - Required parameters enforced
  - Type validation works correctly

- [ ] Test error display
  - Pipeline errors rendered with stage context
  - Retry button appears and works
  - Error details can be expanded
  - Suggested actions displayed

- [ ] Test format switching
  - Format dropdown works
  - Format change triggers re-render
  - Format persists in URL
  - Invalid formats handled gracefully

**Streaming Report Tests** (`test/ash_reports_demo_web/live/report_live/streaming_test.exs`)
- [ ] Test streaming initialization
- [ ] Test progress updates
- [ ] Test pause/resume/cancel operations
- [ ] Test chunk assembly
- [ ] Test completion handling

**Library Tests** (`test/ash_reports_demo_web/live/report_live/library_test.exs`)
- [ ] Test report listing
- [ ] Test search functionality
- [ ] Test category filtering
- [ ] Test favorites toggling
- [ ] Test recent reports tracking

**Chart Gallery Tests** (`test/ash_reports_demo_web/live/chart_live/gallery_test.exs`)
- [ ] Test chart examples display
- [ ] Test interactive demos
- [ ] Test code snippet copying
- [ ] Test navigation to preview

**Chart Preview Tests** (`test/ash_reports_demo_web/live/chart_live/preview_test.exs`)
- [ ] Test chart generation
- [ ] Test configuration updates
- [ ] Test real-time preview
- [ ] Test export functionality

**Performance Dashboard Tests** (`test/ash_reports_demo_web/live/dashboard_live/performance_test.exs`)
- [ ] Test metrics display
- [ ] Test real-time updates
- [ ] Test metric calculations
- [ ] Test historical data

---

### 6.1.2 Component Tests

**Files**: Multiple test files in `test/ash_reports_demo_web/components/`
**Estimated Lines**: ~600 total

#### Tasks

**Parameter Form Tests** (`parameter_form_test.exs`)
- [ ] Test form generation from parameters
  ```elixir
  test "generates form fields from parameter definitions" do
    parameters = [
      %{name: :region, type: :string, required: true},
      %{name: :tier, type: :atom, constraints: [one_of: [:bronze, :silver, :gold]]}
    ]

    rendered = render_component(&ParameterForm.parameter_form/1, parameters: parameters)

    assert rendered =~ ~s(name="region")
    assert rendered =~ ~s(type="text")
    assert rendered =~ ~s(name="tier")
    assert rendered =~ ~s(<option value="bronze")
  end
  ```

- [ ] Test validation logic
  - Required field validation
  - Type validation (string, integer, date, etc.)
  - Constraint validation (one_of, min, max)
  - Error message display

- [ ] Test submission handling
  - Valid form submits successfully
  - Invalid form shows errors
  - Values properly encoded for pipeline

**Chart Viewer Tests** (`chart_viewer_test.exs`)
- [ ] Test chart rendering for all types
  ```elixir
  for chart_type <- [:bar, :line, :pie, :area, :scatter] do
    test "renders #{chart_type} chart", %{data: data, config: config} do
      rendered = render_component(&ChartViewer.chart_viewer/1,
        chart_type: unquote(chart_type),
        data: data,
        config: config
      )

      assert rendered =~ ~s(<svg)
      assert rendered =~ ~s(class="chart-container")
    end
  end
  ```

- [ ] Test responsive sizing
- [ ] Test theme application
- [ ] Test error fallback

**Report Progress Tests** (`report_progress_test.exs`)
- [ ] Test progress bar rendering
- [ ] Test stage indicators
- [ ] Test ETA calculation
- [ ] Test cancel button

**Format Selector Tests** (`format_selector_test.exs`)
- [ ] Test format options display
- [ ] Test selection handling
- [ ] Test disabled formats

**Export Menu Tests** (`export_menu_test.exs`)
- [ ] Test menu toggle
- [ ] Test export actions
- [ ] Test loading states

---

### 6.1.3 Integration Tests

**Files**: Test files in `test/ash_reports_demo_web/integration/`
**Estimated Lines**: ~500 total

#### Tasks

**Pipeline Integration Tests** (`pipeline_integration_test.exs`)
- [ ] End-to-end report execution
  ```elixir
  test "executes customer_summary report through full pipeline" do
    # Generate test data
    AshReportsDemo.DataGenerator.generate_sample_data(:small)

    # Execute report
    {:ok, result} = AshReportsDemoWeb.Reports.PipelineClient.run_report(
      AshReportsDemo.Domain,
      :customer_summary,
      %{region: "CA"},
      format: :html
    )

    # Verify result
    assert result.format == :html
    assert result.metadata.record_count > 0
    assert is_binary(result.content)
    assert String.contains?(result.content, "Customer Summary")

    # Verify pipeline stages executed
    assert :data_loading in result.metadata.stages_executed
    assert :context_building in result.metadata.stages_executed
    assert :rendering in result.metadata.stages_executed
  end
  ```

- [ ] Test all 4 existing reports
  - `:customer_summary`
  - `:product_inventory`
  - `:invoice_details`
  - `:financial_summary`

- [ ] Test all output formats for each report
  - HTML rendering
  - PDF generation
  - JSON structure
  - HEEX component

- [ ] Test error scenarios
  - Invalid report name
  - Invalid parameters
  - Missing data
  - Renderer failures

**Chart Integration Tests** (`chart_integration_test.exs`)
- [ ] Test chart generation from report data
  ```elixir
  test "generates bar chart from sales report data" do
    # Execute report
    {:ok, result} = run_report(:sales_with_chart, %{})

    # Extract chart data
    chart_data = AshReportsDemoWeb.Reports.ChartDataExtractor.extract(
      result,
      %{data_source: :records, category_field: :month, value_field: :total}
    )

    # Generate chart
    {:ok, svg} = AshReports.Charts.generate(:bar, chart_data, %{})

    assert is_binary(svg)
    assert String.starts_with?(svg, "<svg")
  end
  ```

- [ ] Test chart embedding in reports
- [ ] Test all chart types
- [ ] Test chart caching

**Streaming Integration Tests** (`streaming_integration_test.exs`)
- [ ] Test streaming pipeline execution
  ```elixir
  test "streams large report with progress tracking" do
    # Generate large dataset
    AshReportsDemo.DataGenerator.generate_sample_data(:large)

    # Start streaming
    {:ok, stream_id, _pid} = StreamingRunner.start_stream(
      :customer_summary,
      %{},
      progress_callback: fn progress ->
        send(self(), {:progress, progress})
      end
    )

    # Collect progress updates
    progress_updates = collect_progress_updates()

    assert length(progress_updates) > 0
    assert List.last(progress_updates).percent_complete == 100
  end
  ```

- [ ] Test progress tracking accuracy
- [ ] Test pause/resume functionality
- [ ] Test cancellation

---

### 6.1.4 JavaScript/Alpine.js Tests

**Files**: JavaScript test files (if applicable)
**Estimated Lines**: ~200

#### Tasks
- [ ] Test chart interactions
  - Tooltip display on hover
  - Legend click interactions
  - Data point selection

- [ ] Test progress updates
  - WebSocket connection
  - Message handling
  - UI updates

- [ ] Test WebSocket connections
  - Connection establishment
  - Reconnection logic
  - Error handling

- [ ] Test local storage
  - Theme persistence
  - Favorites storage
  - Preferences saving

- [ ] Test keyboard shortcuts
  - Shortcut registration
  - Shortcut execution
  - Conflict prevention

---

### 6.1.5 Performance Tests

**Files**: `test/ash_reports_demo/performance/`
**Estimated Lines**: ~400

#### Tasks

**Report Execution Performance** (`report_execution_test.exs`)
- [ ] Create performance benchmarks
  ```elixir
  test "small report executes within 2 seconds" do
    AshReportsDemo.DataGenerator.generate_sample_data(:small)

    {time_us, {:ok, _result}} = :timer.tc(fn ->
      PipelineClient.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{},
        format: :html
      )
    end)

    time_ms = time_us / 1000
    assert time_ms < 2000, "Expected < 2000ms, got #{time_ms}ms"
  end
  ```

- [ ] Report execution times by size
  - Small reports (<100 records): <2s
  - Medium reports (100-1K records): <10s
  - Large reports (1K-10K records): <30s

- [ ] Chart generation times
  - Standard charts: <500ms
  - Complex charts: <2s

- [ ] Streaming throughput
  - Target: >1000 records/second
  - Measure actual throughput
  - Verify memory stays below 1.5x baseline

- [ ] Memory usage validation
  ```elixir
  test "streaming uses <1.5x memory" do
    baseline_memory = :erlang.memory(:total)

    # Generate large dataset and stream
    AshReportsDemo.DataGenerator.generate_sample_data(:large)

    {:ok, stream_id, _pid} = StreamingRunner.start_stream(
      :customer_summary,
      %{}
    )

    # Measure peak memory during streaming
    peak_memory = monitor_memory_during_stream(stream_id)

    ratio = peak_memory / baseline_memory
    assert ratio < 1.5, "Memory ratio #{ratio} exceeds 1.5x baseline"
  end
  ```

- [ ] Concurrent user simulation
  - Simulate 10+ concurrent report requests
  - Measure response time degradation
  - Check for race conditions

---

## Section 6.2: Documentation

### 6.2.1 User Guide

**Files**: Documentation in `guides/` directory
**Estimated Files**: 5-8 markdown files

#### Tasks

**New UI Walkthrough** (`guides/ui_walkthrough.md`)
- [ ] Screenshot tour of main features
  - Report library
  - Report viewer
  - Chart gallery
  - Streaming reports
  - Performance dashboard

- [ ] Navigation guide
- [ ] Feature highlights
- [ ] Common workflows

**Report Execution Guide** (`guides/running_reports.md`)
- [ ] How to run a report
  - Selecting a report
  - Entering parameters
  - Choosing format
  - Executing and viewing results

- [ ] Parameter guide
  - Parameter types
  - Required vs optional
  - Default values

- [ ] Error troubleshooting
  - Common errors
  - How to read error messages
  - When to retry

**Format Selection Guide** (`guides/output_formats.md`)
- [ ] Format descriptions
  - HTML: Interactive web view
  - PDF: Printable documents
  - JSON: API consumption
  - HEEX: LiveView embedding

- [ ] When to use each format
- [ ] Format-specific features
- [ ] Export and download

**Chart Creation Guide** (`guides/working_with_charts.md`)
- [ ] Chart types overview
- [ ] Configuration options
- [ ] Data requirements
- [ ] Theming and customization

**Streaming Reports Guide** (`guides/streaming_reports.md`)
- [ ] When to use streaming
- [ ] Progress tracking
- [ ] Pause/resume/cancel
- [ ] Memory considerations

---

### 6.2.2 Developer Guide

**Files**: Technical documentation
**Estimated Files**: 6-10 markdown files

#### Tasks

**Architecture Overview** (`guides/architecture.md`)
- [ ] System architecture diagram
- [ ] Pipeline architecture
  - Data Loading stage
  - Context Building stage
  - Rendering stage

- [ ] Component relationships
- [ ] Data flow
- [ ] Technology stack

**Component Structure** (`guides/components.md`)
- [ ] LiveView modules
- [ ] Functional components
- [ ] GenServer modules
- [ ] Channels

**Adding New Reports** (`guides/adding_reports.md`)
- [ ] Report DSL walkthrough
  ```markdown
  ## Defining a New Report

  1. Add report definition in `lib/ash_reports_demo/domain.ex`:

  \`\`\`elixir
  report :my_report do
    description "My custom report"
    driving_resource MyResource

    parameter :filter_field, :string

    variable :total, :sum do
      expression expr(amount)
    end

    band :detail do
      # Band configuration
    end
  end
  \`\`\`

  2. Generate sample data if needed
  3. Test the report
  4. Add to report library
  ```

- [ ] Parameter configuration
- [ ] Variable definitions
- [ ] Band structure
- [ ] Testing new reports

**Adding New Chart Types** (`guides/custom_charts.md`)
- [ ] Chart type registration
- [ ] Data format requirements
- [ ] Renderer implementation
- [ ] Testing charts

**Extending the UI** (`guides/extending_ui.md`)
- [ ] Adding new LiveView pages
- [ ] Creating components
- [ ] Styling guidelines
- [ ] Best practices

---

### 6.2.3 API Documentation

**Files**: API reference documentation
**Estimated Lines**: ~500

#### Tasks

**REST API Endpoints** (`guides/api_reference.md`)
- [ ] Document all endpoints
  ```markdown
  ## GET /api/reports

  List all available reports.

  **Response:**
  \`\`\`json
  {
    "reports": [
      {
        "name": "customer_summary",
        "title": "Customer Summary Report",
        "description": "...",
        "parameters": [...]
      }
    ]
  }
  \`\`\`

  ## GET /api/reports/:name

  Execute a report and return JSON data.

  **Parameters:**
  - `name` (path): Report name
  - Query parameters as defined by report

  **Response:**
  \`\`\`json
  {
    "data": {
      "records": [...],
      "variables": {...}
    },
    "metadata": {...},
    "pagination": {...}
  }
  \`\`\`
  ```

- [ ] Request/response examples
- [ ] Authentication requirements
- [ ] Rate limiting documentation
- [ ] Error responses

**Pipeline Client API** (`guides/pipeline_client_api.md`)
- [ ] `PipelineClient` module documentation
- [ ] Function signatures
- [ ] Usage examples
- [ ] Error handling

---

## Deliverables

### Testing Deliverables
- [ ] LiveView test suite (~800 lines)
- [ ] Component test suite (~600 lines)
- [ ] Integration test suite (~500 lines)
- [ ] JavaScript test suite (~200 lines)
- [ ] Performance test suite (~400 lines)
- [ ] **Total**: ~2,500 lines of test code

### Documentation Deliverables
- [ ] User guide (5-8 documents)
- [ ] Developer guide (6-10 documents)
- [ ] API reference
- [ ] README updates
- [ ] CHANGELOG

### Quality Metrics
- [ ] 80%+ test coverage achieved
- [ ] All tests passing
- [ ] No compilation warnings
- [ ] Credo checks passing
- [ ] Documentation complete and accurate

---

## Testing Strategy

### Test Categories

1. **Unit Tests** (30% of effort)
   - Individual functions and modules
   - Pure logic testing
   - Mock external dependencies

2. **Integration Tests** (40% of effort)
   - Multiple components together
   - Full pipeline execution
   - Database interactions
   - External service calls

3. **E2E Tests** (20% of effort)
   - Complete user workflows
   - Browser-based testing
   - Real data generation

4. **Performance Tests** (10% of effort)
   - Benchmarking
   - Load testing
   - Memory profiling

### Test Execution

```bash
# Run all tests
mix test

# Run specific test file
mix test test/ash_reports_demo_web/live/report_live/viewer_test.exs

# Run with coverage
mix test --cover

# Run performance tests
mix test --only performance

# Run integration tests only
mix test --only integration
```

---

## Documentation Strategy

### Documentation Types

1. **User Documentation**
   - How-to guides
   - Screenshots and videos
   - Common workflows
   - Troubleshooting

2. **Developer Documentation**
   - Architecture diagrams
   - Code examples
   - API references
   - Contribution guidelines

3. **API Documentation**
   - Endpoint descriptions
   - Request/response formats
   - Authentication
   - Rate limits

### Documentation Tools

- Markdown for guides
- ExDoc for code documentation
- Mermaid for diagrams
- Screenshots/screencasts for UI

---

## Final Validation Checklist

### Functionality
- [ ] All 4 reports work through pipeline
- [ ] All 4 output formats functional
- [ ] All 5 chart types display correctly
- [ ] Streaming works for large datasets
- [ ] Progress tracking accurate
- [ ] Error handling comprehensive

### Performance
- [ ] Report execution meets targets
- [ ] Chart generation under 500ms
- [ ] Streaming throughput >1000 rec/s
- [ ] Memory usage within limits
- [ ] Concurrent requests handled

### Quality
- [ ] 80%+ test coverage
- [ ] Zero compilation warnings
- [ ] Credo checks pass
- [ ] Documentation complete
- [ ] No known critical bugs

### User Experience
- [ ] Mobile responsive
- [ ] Dark mode works
- [ ] Keyboard shortcuts functional
- [ ] Tooltips helpful
- [ ] Error messages clear

### Production Readiness
- [ ] Logging configured
- [ ] Monitoring in place
- [ ] Performance metrics tracked
- [ ] Error tracking enabled
- [ ] Deployment tested

---

## Success Criteria

Upon completion of Phase 6, the project should meet all these criteria:

### Test Coverage
- [ ] Overall test coverage ≥80%
- [ ] Critical paths 100% covered
- [ ] All integration tests passing
- [ ] Performance tests validating targets

### Documentation
- [ ] User guide complete
- [ ] Developer guide complete
- [ ] API reference complete
- [ ] All public APIs documented

### Quality
- [ ] No compilation warnings
- [ ] Credo score: A or better
- [ ] Dialyzer no errors
- [ ] Security audit passed

### Performance
- [ ] All performance targets met
- [ ] Load testing successful
- [ ] Memory leaks addressed
- [ ] Optimization opportunities identified

---

## Project Completion

After Phase 6, the AshReports Demo UI Modernization project is complete and ready for:

1. **Deployment to production**
2. **User training and onboarding**
3. **Monitoring and maintenance**
4. **Future enhancements**

The application now showcases the full capabilities of the AshReports library with a modern, performant, and well-tested user interface.
