# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AshReportsDemo is a demonstration application for the AshReports library, showcasing a complete business invoicing system. It uses the Ash Framework with ETS data layer (no database required) and Phoenix LiveView for the web interface.

## Common Commands

### Development

```bash
# Install dependencies
mix deps.get

# Generate demo datasets (required before first run, takes ~10-15 minutes)
mix demo.generate_json

# Generate specific datasets only
mix demo.generate_json --only small
mix demo.generate_json --only medium

# Start Phoenix server
mix phx.server

# Start interactive session
iex -S mix

# Build assets
mix assets.build
```

### Testing

```bash
# Run all tests
mix test

# Run a specific test file
mix test test/path/to/test_file.exs

# Run a specific test by line number
mix test test/path/to/test_file.exs:42

# Run tests with coverage
mix test.coverage

# Exclude slow/benchmark tests (default)
mix test --exclude benchmark --exclude slow
```

### Code Quality

```bash
# Run Credo linter
mix credo

# Run strict Credo checks
mix credo --strict

# Format code
mix format

# Generate documentation
mix docs
```

## Architecture

### Core Domain Model

The application uses Ash Framework's domain-driven design centered on `AshReportsDemo.Domain` which defines:

- **Resources**: Customer, CustomerAddress, CustomerType, Product, ProductCategory, Inventory, Invoice, InvoiceLineItem, SessionMetrics, SessionSnapshot, TelemetryEvent, TelemetryMetric
- **Reports**: 4 comprehensive reports (customer_summary, product_inventory, invoice_details, financial_summary)
- **Charts**: 15 declarative chart definitions using 7 AshReports chart types (pie, line, bar, area, scatter, gantt)

### Key Directories

- `lib/ash_reports_demo/` - Core business logic
  - `resources/` - Ash resources with ETS data layer
  - `domain.ex` - Main domain with reports and charts
  - `data_generator.ex` - Sample data generation
- `lib/ash_reports_demo_web/` - Phoenix web layer
  - `live/` - LiveView modules for reports, charts, dashboard
  - `components/` - Reusable UI components
  - `controllers/` - API and PDF controllers
- `lib/mix/tasks/` - Custom mix tasks
- `test/` - ExUnit tests with PhoenixTest for integration

### Data Layer

All resources use `Ash.DataLayer.Ets` for zero-configuration operation. Data is generated from JSON files in `priv/demo_data/` and loaded into ETS tables at startup.

### Report System

Reports are defined declaratively in the domain using AshReports DSL:
- Base filters with parameters
- Variables (count, sum, average) at report and group levels
- Bands (title, column_header, detail, group_header/footer, summary)
- Multi-level grouping

### Application Supervision Tree

Started in `AshReportsDemo.Application`:
1. DataGenerator - Manages sample data
2. PdfStore - PDF generation storage
3. SessionTracker - User session tracking
4. TelemetryCollector - Performance metrics
5. Phoenix.PubSub
6. Endpoint

## Ash Framework Guidelines

This project follows Ash Framework patterns. Key principles from `deps/ash/usage-rules.md`:

### Code Interfaces

Define code interfaces on domains rather than calling Ash directly:

```elixir
# Good - use code interface
MyDomain.get_customer!(id, load: [:addresses])

# Avoid - direct Ash calls in web modules
Ash.get!(Customer, id) |> Ash.load!([:addresses])
```

### Queries

Always `require Ash.Query` when using `Ash.Query.filter/2` (it's a macro):

```elixir
require Ash.Query
Customer |> Ash.Query.filter(status == :active) |> Ash.read!()
```

### Actions

- Create specific, well-named actions rather than generic CRUD
- Put business logic inside actions using hooks
- Use `!` variants (raising) when expecting success

### Resources

- Resources use ETS tables (e.g., `:demo_customers`)
- IDs are UUIDs with `writable? true` for seeding
- Calculations support both expressions and module-based logic
- Aggregates provide derived data from relationships

## Testing Patterns

Tests use PhoenixTest for LiveView integration testing:

```elixir
use AshReportsDemoWeb.ConnCase

test "example", %{conn: conn} do
  conn
  |> visit("/reports")
  |> assert_has("h1", text: "Reports")
end
```

For resource tests, control data generation explicitly:

```elixir
setup do
  AshReportsDemo.DataGenerator.reset_data()
  AshReportsDemo.generate_sample_data(:small)
  :ok
end
```

## Interactive Demo

```elixir
# In iex -S mix
AshReportsDemo.generate_sample_data(:medium)
AshReportsDemo.data_summary()
AshReportsDemo.list_reports()
AshReportsDemo.run_report(:customer_summary, %{}, format: :html)
```

## Custom Slash Commands

This project has extensive custom Claude commands in `.claude/commands/`:

- `/fix` - Bug fix workflow with investigation and regression tests
- `/review` - Parallel code review with multiple specialized agents
- `/feature` - Feature implementation workflow
- `/plan` - Task planning
- `/commit` - Git commit workflow
- `/pr` - Pull request creation

## Dependencies

Core dependencies:
- `ash` ~> 3.5 - Ash Framework
- `ash_reports` - Path dependency to sibling project
- `phoenix` ~> 1.7 with LiveView
- `phoenix_test` - Integration testing

The ash_reports library is a local path dependency at `../ash_reports`.
- Always ask Pascal to run the server, never ever start it yourself unless when testing