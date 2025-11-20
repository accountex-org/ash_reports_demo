# Multi-Tenancy Datasets Implementation - Progress Summary

**Date**: 2025-11-20
**Branch**: `feature/multi-tenancy-datasets`
**Status**: Core Implementation Complete

## Summary

Implemented Ash's attribute-based multitenancy to load all datasets (small/medium/large) simultaneously at startup, each with their own `dataset_id` tenant identifier. Dataset switching is now instant since all data is pre-loaded.

## Completed Work

### Step 1: Resource Multitenancy Configuration (DONE)

Added multitenancy DSL and `dataset_id` attribute to all 8 core demo data resources:

1. **CustomerType** - `lib/ash_reports_demo/resources/customer_type.ex`
2. **ProductCategory** - `lib/ash_reports_demo/resources/product_category.ex`
3. **Customer** - `lib/ash_reports_demo/resources/customer.ex`
4. **CustomerAddress** - `lib/ash_reports_demo/resources/customer_address.ex`
5. **Product** - `lib/ash_reports_demo/resources/product.ex`
6. **Inventory** - `lib/ash_reports_demo/resources/inventory.ex`
7. **Invoice** - `lib/ash_reports_demo/resources/invoice.ex`
8. **InvoiceLineItem** - `lib/ash_reports_demo/resources/invoice_line_item.ex`

Each resource now has:
```elixir
multitenancy do
  strategy :attribute
  attribute :dataset_id
end

attributes do
  attribute :dataset_id, :string do
    description "Dataset this record belongs to (small/medium/large/huge)"
    allow_nil? false
    writable? true
  end
end
```

### Step 2: Update DataGenerator (DONE)

Modified `lib/ash_reports_demo/data_generator.ex`:

- **Load ALL datasets at startup**: Instead of loading just one dataset, the init process now loads small, medium, and large datasets sequentially, each with its own `dataset_id`
- **Pass tenant to Ash.bulk_create**: Added `tenant: dataset_id` option to bulk create operations
- **Instant dataset switching**: `switch_to_dataset/1` now just updates state since all data is pre-loaded
- **Updated `load_records_via_ash/3`**: Now accepts `dataset_id` and sets it on each record

Key changes:
```elixir
# Load ALL datasets into memory at startup
Enum.each(available_volumes, fn volume ->
  file_path = Path.join(data_dir, "#{volume}.json")
  load_dataset_from_json_file(file_path)
end)

# Pass tenant to Ash operations
Ash.bulk_create(input_maps, resource, :seed,
  domain: AshReportsDemo.Domain,
  tenant: dataset_id,
  ...
)
```

### Step 3: Update DataSummaryComponent (DONE)

Modified `lib/ash_reports_demo_web/components/data_summary_component.ex`:

- **Pass tenant to all Ash.read!() calls**: Updated all 8 CSV generation functions to accept and use tenant
- **Get tenant from current dataset**: `generate_csv_data/1` gets current dataset from DataGenerator and converts to string for tenant

```elixir
defp generate_csv_data(data_type) do
  current_dataset = AshReportsDemo.DataGenerator.get_current_dataset()
  tenant = Atom.to_string(current_dataset)

  case data_type do
    "customers" -> generate_customers_csv(tenant)
    ...
  end
end

defp generate_customers_csv(tenant) do
  Customer
  |> Ash.read!(tenant: tenant)
  |> Enum.sort_by(& &1.name)
  ...
end
```

## Current Behavior

1. **Startup**: All three datasets (small, medium, large) are loaded into ETS with their respective `dataset_id` values
2. **Dataset switching**: Instant - just updates the `current_dataset` state in DataGenerator
3. **CSV generation**: Queries filter by tenant to return only records from the selected dataset
4. **Data counts**: Retrieved from pre-calculated metadata (no live queries needed)

## Remaining Work (Future Enhancement)

### Per-Session Tenant Assignment

The current implementation uses a global `current_dataset` in DataGenerator. For true per-user isolation:

1. Create `TenantHook` LiveView hook to store tenant in socket assigns
2. Store user's dataset selection in Phoenix session
3. Pass tenant from socket assigns to components
4. Each user sees their own dataset selection independently

This would allow multiple users to view different datasets simultaneously without affecting each other.

### Update All Ash Queries Throughout App

Other parts of the application that query Ash resources will need to pass tenant:
- Report queries
- Chart data queries
- Any other live views or components

### Testing

- Unit tests for tenant isolation
- Verify records with dataset_id="small" aren't returned when tenant="medium"
- Integration tests for multi-user scenarios

## How to Test

1. Start the application: `mix phx.server`
2. Navigate to the data summary page
3. Select different dataset sizes from the dropdown
4. Click on data types to view CSV data - it should show only records from the selected dataset
5. Check logs to verify all three datasets loaded at startup

## Files Changed

- `lib/ash_reports_demo/resources/customer_type.ex`
- `lib/ash_reports_demo/resources/product_category.ex`
- `lib/ash_reports_demo/resources/customer.ex`
- `lib/ash_reports_demo/resources/customer_address.ex`
- `lib/ash_reports_demo/resources/product.ex`
- `lib/ash_reports_demo/resources/inventory.ex`
- `lib/ash_reports_demo/resources/invoice.ex`
- `lib/ash_reports_demo/resources/invoice_line_item.ex`
- `lib/ash_reports_demo/data_generator.ex`
- `lib/ash_reports_demo_web/components/data_summary_component.ex`
- `notes/features/multi-tenancy-datasets.md` (planning doc)

## Architecture Notes

- Session resources (SessionMetrics, SessionSnapshot, TelemetryEvent, TelemetryMetric) are NOT part of the multitenancy scope - they track system performance, not demo data
- Identities are automatically scoped to tenants (same email can exist in different datasets)
- Memory usage increases ~3x with all datasets loaded simultaneously (small + medium + large)
- Loading time at startup is ~6-7 seconds for all three datasets
