# AshReports Demo

A comprehensive demonstration of the AshReports library featuring a complete business invoicing system with customers, products, and invoices.

## Quick Start

### First Time Setup (Required)

**Before starting the server**, you must generate the demo datasets. This is a **one-time operation** that takes ~10-15 minutes:

```bash
# Install dependencies
mix deps.get

# Generate all datasets (REQUIRED before first run)
mix demo.generate_json

# This creates JSON files in priv/demo_data/:
# - small.json (~400 KB)
# - medium.json (~2 MB)
# - large.json (~20 MB)
# - huge.json (~500 MB)
```

Alternatively, generate only specific datasets:

```bash
# Generate only the small and medium datasets
mix demo.generate_json --only small
mix demo.generate_json --only medium
```

> **⚠️ Important**: The application will not have any data until you run `mix demo.generate_json`. The server will start but you won't be able to view reports without data.

### Starting the Application

```bash
# Start Phoenix server (loads from JSON automatically)
mix phx.server

# Or start interactive session
iex -S mix

# Switch between datasets dynamically
AshReportsDemo.generate_sample_data(:medium)

# Get data summary
AshReportsDemo.data_summary()

# List available reports
AshReportsDemo.list_reports()
```

### Performance Benefits

- **Startup time**: 10-30 seconds (instead of 5-10 minutes)
- **Deterministic data**: Same data every time (better for testing)
- **Regenerate anytime**: Simply run `mix demo.generate_json` again

## Project Structure

This demo showcases:

- **Phase 7.1**: Project structure and dependencies ✅
- **Phase 7.2**: Domain model and business resources (upcoming)
- **Phase 7.3**: Data generation with Faker (upcoming)
- **Phase 7.4**: Advanced Ash features (upcoming)
- **Phase 7.5**: Comprehensive report definitions (upcoming)
- **Phase 7.6**: Integration and documentation (upcoming)

## Current Status

Phase 7.1 provides:
- Complete Phoenix project structure
- Ash domain configuration
- ETS data layer for zero-configuration operation
- Data generation framework
- Basic testing infrastructure

## Development

```bash
# Run tests
mix test

# Check code quality
mix credo

# Generate documentation
mix docs
```

## Features (Coming in Later Phases)

- Realistic business data with Faker integration
- 8 interconnected business resources
- 4 comprehensive reports showcasing all AshReports features
- Multi-format output (HTML, HEEX, PDF, JSON)
- Interactive demos and performance benchmarks