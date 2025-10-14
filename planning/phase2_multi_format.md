# Phase 2: Multi-Format Output Support

**Duration**: 1-2 weeks
**Goal**: Add support for all renderer formats with download capabilities
**Prerequisites**: Phase 1 (Core Pipeline Integration) completed

---

## Overview

Phase 2 extends the basic pipeline integration from Phase 1 to support all four AshReports output formats (HTML, PDF, JSON, HEEX) with proper display, download, and API capabilities. This phase creates format-specific handlers, export functionality, and REST API endpoints for programmatic access.

**Key Deliverable**: Complete multi-format support with downloadable PDFs, JSON API, and HEEX components.

---

## Section 2.1: Format Rendering Components

### 2.1.1 HTML Renderer Integration

**File**: `lib/ash_reports_demo_web/components/html_report_viewer.ex`
**Estimated Lines**: ~150

#### Purpose
Display HTML-rendered reports with responsive styling and print support.

#### Tasks
- [ ] Create `HtmlReportViewer` functional component
  ```elixir
  defmodule AshReportsDemoWeb.Components.HtmlReportViewer do
    use Phoenix.Component

    attr :content, :string, required: true
    attr :metadata, :map, default: %{}
    attr :print_mode, :boolean, default: false

    def html_report_viewer(assigns)
  end
  ```

- [ ] Display HTML output with CSS styling
  - Render HTML content in iframe or safe div
  - CSS isolation to prevent conflicts
  - Custom scrollbar for report content
  - Section navigation sidebar

- [ ] Responsive layout for different screen sizes
  ```elixir
  defp render_html_content(assigns) do
    ~H"""
    <div class="html-report-container" data-responsive="true">
      <div class="report-sidebar">
        <%= render_table_of_contents(@content) %>
      </div>
      <div class="report-content">
        <%= raw(sanitize_html(@content)) %>
      </div>
    </div>
    """
  end
  ```

- [ ] Print-friendly styling
  - Print CSS media queries
  - Page break handling
  - Header/footer for print
  - Print preview button

- [ ] Dark mode support
  - Toggle between light/dark themes
  - CSS variables for theming
  - Persist preference in localStorage
  - Auto-detect system preference

- [ ] Interactive elements
  - Collapsible sections
  - Expandable tables
  - Tooltip support
  - Jump-to-section links

#### Component Usage
```heex
<.html_report_viewer
  content={@result.content}
  metadata={@result.metadata}
  print_mode={@print_mode}
/>
```

---

### 2.1.2 PDF Download Handler

**File**: `lib/ash_reports_demo_web/controllers/report_pdf_controller.ex`
**Estimated Lines**: ~100

#### Purpose
Generate and stream PDF reports to the browser with proper headers and error handling.

#### Tasks
- [ ] Create `ReportPdfController` with download action
  ```elixir
  defmodule AshReportsDemoWeb.ReportPdfController do
    use AshReportsDemoWeb, :controller

    alias AshReportsDemoWeb.Reports.PipelineClient

    def download(conn, %{"name" => report_name} = params) do
      # Implementation
    end
  end
  ```

- [ ] Generate PDF via `AshReports.Runner.run_report/4` with `format: :pdf`
  ```elixir
  case PipelineClient.run_report(
    AshReportsDemo.Domain,
    String.to_existing_atom(report_name),
    parse_params(params),
    format: :pdf
  ) do
    {:ok, result} -> serve_pdf(conn, result)
    {:error, reason} -> render_error(conn, reason)
  end
  ```

- [ ] Stream PDF to browser with proper headers
  ```elixir
  defp serve_pdf(conn, result) do
    filename = generate_filename(result.metadata)

    conn
    |> put_resp_content_type("application/pdf")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
    |> send_resp(200, result.content)
  end
  ```

- [ ] Filename generation from report name and timestamp
  ```elixir
  defp generate_filename(metadata) do
    report_name = metadata[:report_name] || "report"
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    "#{report_name}_#{timestamp}.pdf"
  end
  ```

- [ ] Error handling for PDF generation failures
  - Render error page with details
  - Log errors for debugging
  - Suggest actions (retry, change format)
  - Track failure metrics

- [ ] Progress indication for large PDFs
  - Show progress bar during generation
  - Estimated time remaining
  - Cancel option
  - Chunk-based streaming

#### Route Configuration
```elixir
# router.ex
scope "/reports", AshReportsDemoWeb do
  get "/:name/pdf", ReportPdfController, :download
end
```

---

### 2.1.3 JSON API Endpoint

**File**: `lib/ash_reports_demo_web/controllers/report_api_controller.ex`
**Estimated Lines**: ~150

#### Purpose
REST API for programmatic report execution returning JSON output.

#### Tasks
- [ ] Create `ReportApiController` with JSON endpoints
  ```elixir
  defmodule AshReportsDemoWeb.ReportApiController do
    use AshReportsDemoWeb, :controller

    action_fallback AshReportsDemoWeb.FallbackController

    def show(conn, %{"name" => report_name} = params)
    def index(conn, _params)  # List available reports
  end
  ```

- [ ] REST API for report execution
  ```elixir
  def show(conn, %{"name" => report_name} = params) do
    with {:ok, atom_name} <- parse_report_name(report_name),
         {:ok, report_params} <- parse_and_validate_params(params),
         {:ok, result} <- execute_report_json(atom_name, report_params) do
      conn
      |> put_status(200)
      |> json(%{
        data: result.content,
        metadata: result.metadata
      })
    end
  end
  ```

- [ ] JSON output with `format: :json`
  - Structured JSON response
  - Include metadata
  - Pagination support for large results
  - Field filtering options

- [ ] Pagination support for large JSON results
  ```elixir
  defp paginate_json_result(result, page, per_page) do
    records = result.content["records"] || []
    total = length(records)

    paginated = Enum.slice(records, (page - 1) * per_page, per_page)

    %{
      data: paginated,
      pagination: %{
        page: page,
        per_page: per_page,
        total: total,
        total_pages: ceil(total / per_page)
      }
    }
  end
  ```

- [ ] OpenAPI/Swagger documentation
  - Endpoint descriptions
  - Parameter schemas
  - Response schemas
  - Example requests/responses
  - Authentication requirements

- [ ] Rate limiting for API access
  ```elixir
  plug :rate_limit, max_requests: 100, interval: :timer.minutes(1)

  defp rate_limit(conn, opts) do
    # Implementation using plug_rate_limiter or custom solution
  end
  ```

#### API Response Format
```json
{
  "data": {
    "records": [...],
    "variables": {...},
    "groups": {...}
  },
  "metadata": {
    "report_name": "customer_summary",
    "execution_time_ms": 1234,
    "record_count": 500,
    "format": "json",
    "generated_at": "2025-10-14T10:30:00Z"
  },
  "pagination": {
    "page": 1,
    "per_page": 100,
    "total": 500,
    "total_pages": 5
  }
}
```

---

### 2.1.4 HEEX Live Component

**File**: `lib/ash_reports_demo_web/components/heex_report.ex`
**Estimated Lines**: ~100

#### Purpose
Render HEEX output as embedded LiveView component for interactive reports.

#### Tasks
- [ ] Create `HeexReport` functional component
  ```elixir
  defmodule AshReportsDemoWeb.Components.HeexReport do
    use Phoenix.LiveComponent

    def mount(socket) do
      {:ok, socket}
    end

    def render(assigns) do
      # Render HEEX content
    end
  end
  ```

- [ ] Render HEEX output as LiveView component
  - Parse HEEX string
  - Compile to component
  - Render with assigns

- [ ] Real-time data updates
  - Subscribe to data changes
  - Re-render on updates
  - Smooth transitions

- [ ] Interactive filtering and sorting
  ```heex
  <div class="heex-report">
    <div class="controls">
      <input type="search" phx-change="filter" phx-debounce="300" />
      <select phx-change="sort">
        <option value="name">Name</option>
        <option value="date">Date</option>
      </select>
    </div>

    <%= render_dynamic_content(@heex_content, @assigns) %>
  </div>
  ```

- [ ] Integration with Phoenix.Component
  - Use Phoenix.Component for rendering
  - Support assigns and slots
  - Handle events properly

---

## Section 2.2: Format Selection UI

### 2.2.1 Format Selector Component

**File**: `lib/ash_reports_demo_web/components/format_selector.ex`
**Estimated Lines**: ~80

#### Purpose
Reusable component for format selection with descriptions and icons.

#### Tasks
- [ ] Create `FormatSelector` functional component
  ```elixir
  defmodule AshReportsDemoWeb.Components.FormatSelector do
    use Phoenix.Component

    attr :current_format, :atom, required: true
    attr :on_change, :any, required: true
    attr :disabled_formats, :list, default: []

    def format_selector(assigns)
  end
  ```

- [ ] Radio buttons or dropdown for format selection
  ```heex
  <div class="format-selector">
    <div class="format-option" :for={format <- @formats}>
      <input
        type="radio"
        name="format"
        value={format}
        checked={@current_format == format}
        disabled={format in @disabled_formats}
        phx-click="format_selected"
        phx-value-format={format}
      />
      <label>
        <.format_icon type={format} />
        <%= format_label(format) %>
      </label>
    </div>
  </div>
  ```

- [ ] Format descriptions and use cases
  ```elixir
  defp format_description(:html), do: "Interactive web view with styling"
  defp format_description(:pdf), do: "Printable document for archival"
  defp format_description(:json), do: "Structured data for API consumers"
  defp format_description(:heex), do: "LiveView component for embedding"
  ```

- [ ] Preview icons for each format
  - SVG icons for HTML, PDF, JSON, HEEX
  - Consistent icon styling
  - Accessible labels

- [ ] Disabled states for unavailable formats
  - Grey out unavailable options
  - Tooltip explaining why disabled
  - Configuration-driven availability

---

### 2.2.2 Export Menu Component

**File**: `lib/ash_reports_demo_web/components/export_menu.ex`
**Estimated Lines**: ~100

#### Purpose
Dropdown menu with export actions for different formats.

#### Tasks
- [ ] Create `ExportMenu` functional component
  ```elixir
  defmodule AshReportsDemoWeb.Components.ExportMenu do
    use Phoenix.Component

    attr :report_name, :atom, required: true
    attr :parameters, :map, required: true
    attr :current_result, :map, default: nil

    def export_menu(assigns)
  end
  ```

- [ ] Dropdown menu with export options
  ```heex
  <div class="export-menu" phx-click-away="close_menu">
    <button phx-click="toggle_menu">
      Export ▼
    </button>

    <div class="menu-dropdown" :if={@menu_open}>
      <a href={pdf_download_url(@report_name, @parameters)}>
        <.icon name="hero-document" /> Download as PDF
      </a>
      <!-- Other options -->
    </div>
  </div>
  ```

- [ ] "Download as PDF" action
  - Generate PDF URL with parameters
  - Open in new tab
  - Track download analytics

- [ ] "Export to JSON" action
  - Download JSON file
  - Pretty-printed
  - Filename with timestamp

- [ ] "Print HTML" action
  - Trigger browser print dialog
  - Apply print CSS
  - Suggest landscape mode

- [ ] "Copy as HEEX" action
  - Copy HEEX string to clipboard
  - Show success notification
  - Format with proper indentation

- [ ] Loading states during export
  - Show spinner on button
  - Disable menu during export
  - Progress indication

---

## Section 2.3: Router Updates

### 2.3.1 Route Configuration

**File**: `lib/ash_reports_demo_web/router.ex` (MODIFY EXISTING)
**Estimated Changes**: ~30 lines

#### Tasks
- [ ] Add PDF download route
  ```elixir
  scope "/reports", AshReportsDemoWeb do
    pipe_through :browser

    get "/:name/pdf", ReportPdfController, :download
  end
  ```

- [ ] Add JSON API route
  ```elixir
  scope "/api/reports", AshReportsDemoWeb do
    pipe_through :api

    get "/", ReportApiController, :index
    get "/:name", ReportApiController, :show
  end
  ```

- [ ] Add HEEX component route
  ```elixir
  scope "/reports", AshReportsDemoWeb do
    pipe_through :browser

    live "/:name/component", ReportLive.HeexViewer
  end
  ```

- [ ] Update existing report viewer routes
  - Support format query parameter
  - Default to HTML format
  - Redirect old routes

- [ ] Add format-specific routes
  - `/reports/:name/html` - HTML view
  - `/reports/:name/pdf` - PDF download
  - `/reports/:name/json` - JSON data
  - `/reports/:name/component` - HEEX component

---

### 2.3.2 Route Helpers

**File**: `lib/ash_reports_demo_web/reports/routes.ex`
**Estimated Lines**: ~80

#### Purpose
Helper functions for generating report URLs with parameters and format options.

#### Tasks
- [ ] Create `Routes` module with helper functions
  ```elixir
  defmodule AshReportsDemoWeb.Reports.Routes do
    def report_url(report_name, params \\ %{}, format \\ :html)
    def pdf_download_url(report_name, params \\ %{})
    def json_api_url(report_name, params \\ %{})
    def heex_component_url(report_name, params \\ %{})
  end
  ```

- [ ] Helper functions for report URLs
  ```elixir
  def report_url(report_name, params, format) do
    path = "/reports/#{report_name}"
    query = URI.encode_query(Map.put(params, :format, format))
    "#{path}?#{query}"
  end
  ```

- [ ] Format-specific URL generation
  - PDF: Include all parameters in URL
  - JSON: Add pagination params
  - HEEX: Include interactive options

- [ ] Parameter encoding for URLs
  - Properly encode special characters
  - Handle nested parameters
  - Preserve types (dates, atoms)

- [ ] Signed URLs for authenticated downloads
  ```elixir
  def signed_pdf_url(report_name, params, user_token) do
    base_url = pdf_download_url(report_name, params)
    signature = generate_signature(base_url, user_token)
    "#{base_url}&signature=#{signature}"
  end
  ```

---

## Deliverables

### Code Deliverables
- [ ] `HtmlReportViewer` component - HTML display with styling
- [ ] `ReportPdfController` - PDF download handler
- [ ] `ReportApiController` - JSON API endpoints
- [ ] `HeexReport` component - HEEX LiveComponent
- [ ] `FormatSelector` component - Format selection UI
- [ ] `ExportMenu` component - Export dropdown menu
- [ ] `Routes` module - URL helper functions
- [ ] Updated `router.ex` - New routes for all formats

### Documentation
- [ ] API documentation for JSON endpoints
- [ ] Format selection guide
- [ ] Export functionality guide
- [ ] URL structure documentation

### Success Metrics
- [ ] All 4 formats work for all reports
- [ ] PDF downloads work reliably
- [ ] JSON API returns valid data
- [ ] HEEX components render correctly
- [ ] Export actions complete successfully
- [ ] API rate limiting prevents abuse

---

## Testing Requirements

### Unit Tests
- [ ] `HtmlReportViewer` component tests
- [ ] `FormatSelector` component tests
- [ ] `ExportMenu` component tests
- [ ] `Routes` helper function tests

### Integration Tests
- [ ] PDF download end-to-end test
- [ ] JSON API request/response test
- [ ] Format switching test
- [ ] Export menu actions test

### API Tests
- [ ] JSON endpoint response format
- [ ] Pagination functionality
- [ ] Rate limiting behavior
- [ ] Error response formats

---

## Dependencies

### External Dependencies
- None (all dependencies from Phase 1)

### Internal Dependencies
- Phase 1: PipelineClient module
- Phase 1: ResultHandler module
- Phase 1: ReportLive.Viewer

---

## Next Phase

After Phase 2 completion, proceed to:
- **Phase 3**: Chart Integration
  - Builds on multi-format support
  - Adds chart display components
  - Integrates with report results
