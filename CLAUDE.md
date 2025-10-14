# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AshReports Demo is an Elixir/Phoenix application demonstrating the AshReports library through a comprehensive business invoicing system. The project uses the Ash Framework with an ETS-based data layer for zero-configuration operation and includes realistic data generation using Faker.

**Important**: This project has a local path dependency on `ash_reports` located at `../ash_reports`. Ensure this sibling project exists when developing.

## Development Commands

### Setup and Dependencies
```bash
# Install dependencies
mix deps.get

# Compile the project
mix compile

# Setup (deps + compile)
mix setup
```

### Running the Application
```bash
# Start Phoenix server
mix phx.server

# Start interactive session (IEx with Mix)
iex -S mix

# Generate sample data in IEx
AshReportsDemo.DataGenerator.generate_sample_data(:medium)  # :small, :medium, or :large

# Get data summary
AshReportsDemo.EtsDataLayer.table_stats()

# Reset/clear all data
AshReportsDemo.DataGenerator.reset_data()
```

### Testing
```bash
# Run all tests
mix test

# Run specific test file
mix test test/path/to/test_file.exs

# Run tests with a specific line number
mix test test/path/to/test_file.exs:42

# Run with coverage report
mix test.coverage
```

### Code Quality
```bash
# Format code (uses Ash and Phoenix formatter configs)
mix format

# Run static code analysis
mix credo

# Run dialyzer for type checking
mix dialyzer

# Generate documentation
mix docs
```

### Aliases
```bash
# Generate sample data programmatically
mix generate_data

# Start interactive demo
mix demo
```

## Architecture

### Report Execution Pipeline

AshReports uses a **three-stage pipeline architecture** for report execution:

#### Stage 1: Data Loading (AshReports.DataLoader)
- **Stream-based processing** using Elixir streams for memory efficiency
- Integrates with:
  - `QueryBuilder`: Builds optimized Ash queries from report definitions
  - `VariableState`: GenServer managing variable calculations and state
  - `GroupProcessor`: Handles group break detection and processing
  - `Executor`: Coordinates query execution and relationship loading
- Returns structured data with metadata for rendering

#### Stage 2: Context Building (AshReports.RenderContext)
- Creates render context from data loader results
- Merges report definition, data, and render configuration
- Prepares variable state and group information for renderers

#### Stage 3: Rendering (AshReports.RenderPipeline)
The rendering pipeline consists of six sub-stages:
1. **Initialization**: Context validation and setup
2. **Layout Calculation**: Band and element positioning using LayoutEngine
3. **Data Processing**: Record iteration and variable resolution
4. **Element Rendering**: Individual element rendering with format-specific logic
5. **Assembly**: Combining rendered elements into final output
6. **Finalization**: Cleanup and metadata generation

### Core Components

**Domain Model** (`lib/ash_reports_demo/domain.ex`):
- Central Ash Domain definition using `AshReports.Domain` extension
- Defines 8 interconnected business resources representing an invoicing system
- Contains 4 comprehensive report definitions showcasing AshReports features
- Authorization configured with `:when_requested` strategy

**Resources** (`lib/ash_reports_demo/resources/`):
- `Customer`: Customer management with health scores, risk categories, and tier classifications
- `CustomerAddress`: Multiple addresses per customer with address types
- `CustomerType`: Customer tier system (Bronze/Silver/Gold/Platinum)
- `Product`: Product catalog with SKU, pricing, cost, and margin calculations
- `ProductCategory`: Product categorization (Electronics, Clothing, Home & Garden, Books, Sports)
- `Inventory`: Stock tracking with reorder points and location management
- `Invoice`: Invoice management with statuses (draft/sent/paid/overdue/cancelled)
- `InvoiceLineItem`: Line items linking invoices to products with quantities and pricing

**Data Layer** (`lib/ash_reports_demo/ets_data_layer.ex`):
- GenServer managing ETS tables for in-memory storage
- Zero-configuration: No database setup required
- 8 tables corresponding to resources (`:demo_customers`, `:demo_products`, etc.)
- All resources use `data_layer: Ash.DataLayer.Ets`
- Supports concurrent reads/writes with read/write concurrency enabled
- Provides `table_stats/0` for monitoring data volumes

**Data Generation** (`lib/ash_reports_demo/data_generator.ex`):
- GenServer-based transactional data generation with Faker integration
- Three volume configurations: `:small`, `:medium`, `:large`
- Maintains referential integrity across all resources
- Generates realistic business data: names, addresses, SKUs, invoice numbers
- Built-in validation with `validate_data_integrity/0`
- Rollback support on generation failures

**Reports** (defined in `lib/ash_reports_demo/domain.ex`):
1. `:customer_summary` - Multi-level grouping with geographic and tier analysis
2. `:product_inventory` - Inventory with profitability metrics
3. `:invoice_details` - Master-detail financial analysis
4. `:financial_summary` - Executive dashboard

### Web Interface

**Phoenix/LiveView** (`lib/ash_reports_demo_web/`):
- Standard Phoenix 1.7+ structure
- LiveView-based report interfaces in `live/report_live/`
- Routes defined in `router.ex` for `/reports`, `/dashboard`, and `/charts` paths
- Uses Tailwind CSS and esbuild for assets
- Core components in `components/core_components.ex`

### Application Startup

The application (`lib/ash_reports_demo/application.ex`) starts:
1. ETS Data Layer GenServer
2. Data Generator GenServer
3. Phoenix PubSub
4. Phoenix Endpoint

### Relationship Structure

```
CustomerType
    └─ Customer (belongs_to :customer_type)
        ├─ CustomerAddress (has_many :addresses)
        └─ Invoice (has_many :invoices)
            └─ InvoiceLineItem (has_many :line_items)

ProductCategory
    └─ Product (belongs_to :category)
        ├─ Inventory (has_one)
        └─ InvoiceLineItem (has_many :line_items)
```

## Key Patterns and Conventions

### Resource Definitions
- All resources use Ash.Resource with ETS data layer
- UUIDs as primary keys (`:uuid_primary_key`)
- Comprehensive calculations for business intelligence (health scores, risk categories, tiers)
- Aggregates for cross-resource metrics (invoice counts, totals)
- Custom actions for business operations (`:suspend`, `:activate`, `:adjust_credit_limit`)
- Validations include both simple and complex business rules
- Changes track `updated_at` automatically

### Data Generation Flow
1. Foundation data (customer types, product categories) - must be created first
2. Customer data (with addresses)
3. Product data (with inventory)
4. Invoice data (with line items and calculated totals)
5. Validation of referential integrity

### Report Parameters
- Reports support filtering via parameters (`:region`, `:tier`, `:status`, etc.)
- Variables track aggregations (`:count`, `:sum`) with reset points
- Bands organize report structure (`:title`, `:detail`, `:summary`)
- Fields map to resource attributes

### Testing Structure
- Test support files in `test/support/`
- Integration tests for data generation in `test/ash_reports_demo/`
- Web integration tests in `test/ash_reports_demo_web/integration/`
- Report tests in `test/ash_reports_demo/reports/`
- Uses ExCoveralls for coverage reporting

## Report Rendering System

### Available Renderers

AshReports supports multiple output formats through specialized renderers:

- **HTML Renderer** (`AshReports.HtmlRenderer`): Complete HTML documents with CSS
- **HEEX Renderer** (`AshReports.HeexRenderer`): Phoenix LiveView components
- **PDF Renderer** (`AshReports.PdfRenderer`): PDF generation via ChromicPDF
- **JSON Renderer** (`AshReports.JsonRenderer`): Structured JSON output

Each renderer implements:
- `render_with_context/2`: Main rendering function taking RenderContext and options
- `supports_streaming?/0`: Whether the renderer supports streaming output
- `file_extension/0`: File extension for output (e.g., "html", "pdf")
- `content_type/0`: MIME type for HTTP responses

### Streaming Reports

For large datasets, use streaming mode for memory-efficient processing:

```elixir
# Stream-based report execution
{:ok, result} = AshReports.Runner.run_report(
  AshReportsDemo.Domain,
  :financial_summary,
  %{},
  format: :json,
  streaming: true,
  chunk_size: 500
)
```

### Error Handling

The pipeline uses structured error handling with stage information:

```elixir
case AshReportsDemo.run_report(:customer_summary, %{}) do
  {:ok, result} ->
    # Success - access result.content

  {:error, %{stage: stage, reason: reason}} ->
    # Pipeline error with stage context
    IO.puts("Failed at #{stage}: #{inspect(reason)}")

  {:error, reason} ->
    # Other error
end
```

Error stages include:
- `:data_loading` - Data fetching or query building failed
- `:context_building` - Render context creation failed
- `:renderer_selection` - Invalid or unsupported format
- `:rendering` - Renderer execution failed

## Important Notes

1. **Path Dependency**: The `ash_reports` dependency must exist at `../ash_reports` relative to this project
2. **ETS Data Layer**: All data is in-memory and lost on application restart - use data generator to repopulate
3. **PDF Generation Disabled**: ChromicPDF is configured but PDF generation is disabled (`enable_pdf: false`)
4. **Calculations**: Many resource calculations (like `:lifetime_value`, `:customer_health_score`) use demo logic with randomization - real implementations would query actual data
5. **No Database Migrations**: Since this uses ETS, there are no database migrations to manage
6. **Phoenix Test**: Configured to use `AshReportsDemoWeb.Endpoint` for integration testing
7. **Pipeline Architecture**: Reports execute through a three-stage pipeline (data loading → context building → rendering), NOT through simple function calls
8. **Streaming Support**: For large datasets, always use `streaming: true` to prevent memory issues

## Common Development Workflows

### Adding a New Resource
1. Create resource module in `lib/ash_reports_demo/resources/`
2. Add ETS table to `@table_names` in `ets_data_layer.ex`
3. Add resource mapping in `map_resource_to_table/1`
4. Register resource in `lib/ash_reports_demo/domain.ex` under `resources do`
5. Add data generation logic to `data_generator.ex`
6. Update validation logic in `validate_referential_integrity/0`

### Adding a New Report
1. Define report in `lib/ash_reports_demo/domain.ex` under `reports do`
   - Specify `driving_resource`: The main Ash resource to query
   - Add `parameter` entries for user inputs with type validation
   - Define `variable` entries for calculations (`:count`, `:sum`, `:avg`, etc.)
   - Add `group` definitions for multi-level grouping
   - Create `band` definitions (`:title`, `:detail`, `:summary`, `:header`, `:footer`)
2. Create corresponding LiveView in `lib/ash_reports_demo_web/live/report_live/`
   - Use `AshReportsDemo.run_report/3` to execute the report
   - Handle both success and error cases from pipeline
3. Add route in `router.ex`
4. Update report listing in `ReportLive.Index`

### Report Definition Components

**Parameters**: User-provided values that filter/control the report
```elixir
parameter :region, :string
parameter :tier, :string, constraints: [one_of: ["Bronze", "Silver", "Gold"]]
parameter :min_value, :decimal, default: Decimal.new("0.00")
```

**Variables**: Calculated values that accumulate across records
```elixir
variable :customer_count do
  type :count
  expression(expr(1))
  reset_on(:report)  # or :group for group-level variables
end

variable :total_sales do
  type :sum
  expression(expr(total))
  reset_on(:group)
end
```

**Groups**: Define hierarchical grouping for data organization
```elixir
group :region do
  level(1)
  expression(expr(addresses.state))
end

group :tier do
  level(2)
  expression(expr(customer_tier))
end
```

**Bands**: Define report sections and their content
```elixir
band :title do
  type :title

  label :report_title do
    text("Customer Summary Report")
  end
end

band :customer_detail do
  type :detail

  field :name do
    source :name
  end

  field :tier do
    source :customer_tier
  end
end

band :summary do
  type :summary

  label :total do
    text("Total: [customer_count]")  # Variables in square brackets
  end
end
```

### Debugging Data Issues
```elixir
# In IEx
AshReportsDemo.EtsDataLayer.table_stats()                    # See all table sizes
AshReportsDemo.DataGenerator.validate_data_integrity()       # Check referential integrity
:ets.tab2list(:demo_customers)                               # Inspect specific table
Ash.read!(AshReportsDemo.Customer, domain: AshReportsDemo.Domain)  # Read all customers
```

### Working with Reports

The AshReports library uses a sophisticated **GenStage-based pipeline architecture** for data processing and rendering:

```elixir
# In IEx - Basic report execution
{:ok, result} = AshReportsDemo.run_report(:customer_summary, %{region: "CA"}, format: :html)
{:ok, result} = AshReportsDemo.run_report(:financial_summary, %{}, format: :pdf)

# Access the rendered output
result.content          # Binary/string output
result.metadata         # Pipeline metadata (execution time, record count, etc.)
result.format           # Output format

# Direct access to AshReports.Runner API
{:ok, result} = AshReports.Runner.run_report(
  AshReportsDemo.Domain,
  :customer_summary,
  %{region: "CA"},
  format: :html,
  streaming: false
)
```
