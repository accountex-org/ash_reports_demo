# Feature Planning: Refactor Data Loading to Use Ash API

**Status**: Planning
**Priority**: High
**Created**: 2025-11-13
**Complexity**: Medium

---

## Problem Statement

The application currently loads pre-generated JSON datasets by manually inserting records into ETS tables as plain tuples: `{uuid, plain_map}`. However, Ash.DataLayer.Ets expects records with proper Ash metadata, not just plain maps.

### Current Issues

1. **Charts Display Errors**: Charts show "data cannot be empty" errors when querying via `Ash.read!()`
2. **Data Retrieval Inconsistency**: Data Summary page shows correct counts (because it reads from cached metadata in DataGenerator GenServer), but CSV exports and any Ash queries fail
3. **Deserialization Failures**: The system can't deserialize plain maps into proper Ash resource structs
4. **Lack of Ash Metadata**: Manually inserted records lack the internal metadata that Ash expects for proper resource management

### Root Cause

**Location**: `/home/pcharbon/code/ash_reports_demo/lib/ash_reports_demo/data_generator.ex`
**Function**: `convert_json_to_dataset/1` (lines 940-981)
**Current Approach**:
```elixir
# Manual ETS insertion without Ash metadata
:ets.insert(table_name, {uuid, plain_map})
```

This bypasses Ash's create pipeline entirely, resulting in records that exist in ETS but are not properly recognized by Ash's data layer.

---

## Proposed Solution

Use Ash's official bulk create API to insert records properly through the framework's pipeline:

```elixir
# Instead of manual insertion:
:ets.insert(table_name, {uuid, plain_map})

# Use Ash's bulk_create API:
Ash.bulk_create(records, Resource, :create,
  domain: AshReportsDemo.Domain,
  return_records?: false,
  return_errors?: true,
  batch_size: 100,
  assume_casted?: false,
  stop_on_error?: true,
  transaction: :batch
)
```

---

## Resource Loading Order

To maintain referential integrity, resources must be loaded in dependency order:

### Phase 1: Foundation Data
1. `AshReportsDemo.CustomerType` (no dependencies)
2. `AshReportsDemo.ProductCategory` (no dependencies)

### Phase 2: Core Entities
3. `AshReportsDemo.Customer` (depends on CustomerType)
4. `AshReportsDemo.CustomerAddress` (depends on Customer)
5. `AshReportsDemo.Product` (depends on ProductCategory)
6. `AshReportsDemo.Inventory` (depends on Product)

### Phase 3: Transactional Data
7. `AshReportsDemo.Invoice` (depends on Customer)
8. `AshReportsDemo.InvoiceLineItem` (depends on Invoice and Product)

**Rationale**: This order ensures all foreign key references exist before child records are created.

---

## Technical Approach

### 1. Ash.bulk_create Configuration

Based on Ash Framework documentation and project requirements:

```elixir
Ash.bulk_create(records, Resource, :create,
  # Core options
  domain: AshReportsDemo.Domain,

  # Return options - optimize for bulk loading
  return_records?: false,      # Don't return records (saves memory)
  return_errors?: true,        # Collect errors for debugging
  return_stream?: false,       # Not needed for our use case

  # Batch configuration
  batch_size: 100,             # Process 100 records per batch
  max_concurrency: 0,          # Sequential processing (safer for ETS)

  # Validation & processing
  assume_casted?: false,       # Let Ash cast and validate inputs
  stop_on_error?: true,        # Fail fast on errors

  # Transaction control
  transaction: :batch          # Batch-level transactions
)
```

### 2. Data Transformation Pipeline

#### Input Format (from JSON)
```elixir
# JSON structure after parsing
%{
  "demo_customers" => [
    ["uuid-string", %{"name" => "John", "email" => "john@example.com", ...}],
    ...
  ]
}
```

#### Transformation Required
```elixir
# Convert to list of maps for Ash.bulk_create
[
  %{
    id: "uuid-binary",
    name: "John",
    email: "john@example.com",
    status: :active,
    credit_limit: Decimal.new("5000.00"),
    customer_type_id: "type-uuid-binary",
    created_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  },
  ...
]
```

### 3. Field Type Mapping

Special handling required for these field types:

| Field Type | JSON Representation | Elixir Type | Conversion Function |
|-----------|-------------------|------------|-------------------|
| UUID | String (hyphenated) | Binary (16 bytes) | `Ecto.UUID.dump!/1` |
| Decimal | `%{"__decimal__" => "123.45"}` | `Decimal.t()` | `Decimal.new/1` |
| Date | `%{"__date__" => "2024-01-15"}` | `Date.t()` | `Date.from_iso8601!/1` |
| DateTime | `%{"__datetime__" => "2024-01-15T10:30:00Z"}` | `DateTime.t()` | `DateTime.from_iso8601!/1` |
| Atom | String | Atom | `String.to_existing_atom/1` |

### 4. Error Handling Strategy

```elixir
case Ash.bulk_create(records, Resource, :create, opts) do
  %Ash.BulkResult{status: :success, records: _records} ->
    Logger.info("Successfully loaded #{length(records)} #{Resource} records")
    :ok

  %Ash.BulkResult{status: :partial_success, records: records, errors: errors} ->
    Logger.warning("""
    Partial success loading #{Resource}:
    - Loaded: #{length(records)} records
    - Failed: #{length(errors)} records
    """)
    {:error, :partial_success, errors}

  %Ash.BulkResult{status: :error, errors: errors} ->
    Logger.error("Failed to load #{Resource}: #{inspect(errors, pretty: true)}")
    {:error, :bulk_create_failed, errors}
end
```

---

## Implementation Plan

### Step 1: Create New Loading Function (1-2 hours)

**File**: `lib/ash_reports_demo/data_generator.ex`
**Function**: `load_records_via_ash/3`

```elixir
@spec load_records_via_ash(module(), list(map()), keyword()) ::
  :ok | {:error, :partial_success, list()} | {:error, :bulk_create_failed, list()}
defp load_records_via_ash(resource_module, records, opts \\ []) do
  batch_size = Keyword.get(opts, :batch_size, 100)

  # Transform records from JSON format to Ash input format
  ash_inputs = Enum.map(records, &prepare_record_for_ash(resource_module, &1))

  # Bulk create with Ash
  result = Ash.bulk_create(
    ash_inputs,
    resource_module,
    :create,
    domain: AshReportsDemo.Domain,
    return_records?: false,
    return_errors?: true,
    batch_size: batch_size,
    stop_on_error?: true,
    transaction: :batch
  )

  handle_bulk_result(result, resource_module)
end
```

### Step 2: Create Record Transformation Function (1 hour)

**Function**: `prepare_record_for_ash/2`

```elixir
@spec prepare_record_for_ash(module(), tuple()) :: map()
defp prepare_record_for_ash(resource_module, {uuid_key, data_map}) do
  # Get resource attributes
  attributes = Ash.Resource.Info.attributes(resource_module)

  # Start with base map including id
  base_map = %{id: uuid_key}

  # Transform each field in data_map according to resource schema
  Enum.reduce(data_map, base_map, fn {field_key, value}, acc ->
    attribute = Enum.find(attributes, &(&1.name == field_key))

    if attribute do
      converted_value = convert_field_value(value, attribute.type)
      Map.put(acc, field_key, converted_value)
    else
      acc
    end
  end)
end
```

### Step 3: Refactor convert_json_to_dataset/1 (2-3 hours)

Replace manual ETS insertion with Ash API calls:

```elixir
defp convert_json_to_dataset(json_data) do
  try do
    # Define loading order (respecting foreign key dependencies)
    loading_order = [
      {:demo_customer_types, CustomerType},
      {:demo_product_categories, ProductCategory},
      {:demo_customers, Customer},
      {:demo_customer_addresses, CustomerAddress},
      {:demo_products, Product},
      {:demo_inventory, Inventory},
      {:demo_invoices, Invoice},
      {:demo_invoice_line_items, InvoiceLineItem}
    ]

    # Load each resource type in order
    Enum.reduce_while(loading_order, {:ok, []}, fn {table_name, resource}, {:ok, acc} ->
      records = Map.get(json_data, Atom.to_string(table_name), [])

      # Convert JSON format to tuple format
      tuples = convert_json_records_to_tuples(records)

      case load_records_via_ash(resource, tuples) do
        :ok ->
          {:cont, {:ok, [{table_name, length(records)} | acc]}}
        {:error, reason, details} ->
          {:halt, {:error, "Failed to load #{table_name}: #{inspect(reason)}", details}}
      end
    end)
    |> case do
      {:ok, stats} ->
        Logger.info("Successfully loaded dataset: #{inspect(stats)}")
        {:ok, :loaded}
      {:error, reason, details} ->
        {:error, reason, details}
    end
  rescue
    e ->
      {:error, "Failed to load dataset: #{Exception.message(e)}"}
  end
end
```

### Step 4: Add Helper Functions (1 hour)

```elixir
@spec convert_json_records_to_tuples(list()) :: list(tuple())
defp convert_json_records_to_tuples(json_records) do
  Enum.map(json_records, fn [key_map, data_map] ->
    uuid_binary =
      key_map
      |> Map.get("id")
      |> convert_uuid_to_binary()

    converted_data =
      data_map
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), convert_value(v)} end)
      |> Map.new()

    {uuid_binary, converted_data}
  end)
end

@spec convert_field_value(any(), atom()) :: any()
defp convert_field_value(value, :decimal) when is_map(value) do
  case value do
    %{"__decimal__" => str} -> Decimal.new(str)
    _ -> value
  end
end

defp convert_field_value(value, :date) when is_map(value) do
  case value do
    %{"__date__" => str} -> Date.from_iso8601!(str)
    _ -> value
  end
end

defp convert_field_value(value, :utc_datetime_usec) when is_map(value) do
  case value do
    %{"__datetime__" => str} ->
      {:ok, dt, _offset} = DateTime.from_iso8601(str)
      dt
    _ -> value
  end
end

defp convert_field_value(value, :atom) when is_binary(value) do
  String.to_existing_atom(value)
end

defp convert_field_value(value, _type), do: value

@spec convert_uuid_to_binary(binary()) :: binary()
defp convert_uuid_to_binary(uuid_string) when is_binary(uuid_string) do
  case Ecto.UUID.dump(uuid_string) do
    {:ok, binary} -> binary
    :error -> raise "Invalid UUID: #{uuid_string}"
  end
end
```

### Step 5: Update load_dataset_from_json_file/1 (30 minutes)

Ensure the function properly handles the new return format:

```elixir
defp load_dataset_from_json_file(file_path) do
  with {:ok, json_content} <- File.read(file_path),
       {:ok, json_data} <- Jason.decode(json_content),
       {:ok, :loaded} <- convert_json_to_dataset(json_data),
       {:ok, volume} <- extract_volume_from_path(file_path) do
    Logger.info("Loaded #{volume} dataset from #{file_path}")
    {:ok, volume}
  else
    {:error, :enoent} ->
      {:error, "File not found: #{file_path}"}

    {:error, %Jason.DecodeError{} = error} ->
      {:error, "Failed to parse JSON: #{Exception.message(error)}"}

    {:error, reason, _details} ->
      {:error, "Failed to load dataset: #{inspect(reason)}"}

    {:error, reason} ->
      {:error, "Failed to load dataset: #{inspect(reason)}"}
  end
end
```

### Step 6: Testing Strategy (2-3 hours)

#### Unit Tests

**File**: `test/ash_reports_demo/data_generator_ash_loading_test.exs`

```elixir
defmodule AshReportsDemo.DataGeneratorAshLoadingTest do
  use AshReportsDemo.DataCase

  alias AshReportsDemo.{DataGenerator, Customer, Product, Invoice}

  describe "load_records_via_ash/3" do
    test "successfully loads valid customer records" do
      records = [
        {Ecto.UUID.dump!("00000000-0000-0000-0000-000000000001"),
         %{name: "John Doe", email: "john@example.com", status: :active}}
      ]

      assert :ok = DataGenerator.load_records_via_ash(Customer, records)

      customers = Ash.read!(Customer)
      assert length(customers) == 1
      assert hd(customers).name == "John Doe"
    end

    test "handles invalid records gracefully" do
      records = [
        {Ecto.UUID.dump!("00000000-0000-0000-0000-000000000001"),
         %{name: nil, email: "invalid"}}  # name is required
      ]

      assert {:error, :bulk_create_failed, _errors} =
        DataGenerator.load_records_via_ash(Customer, records)
    end

    test "handles partial success with stop_on_error?: false" do
      # Test with mixed valid/invalid records
    end
  end

  describe "prepare_record_for_ash/2" do
    test "correctly transforms customer record" do
      # Test field transformations
    end

    test "handles special field types (Decimal, Date, DateTime)" do
      # Test type conversions
    end
  end

  describe "convert_json_to_dataset/1" do
    test "loads complete dataset in correct order" do
      # Test full dataset loading
    end

    test "maintains referential integrity" do
      # Verify foreign keys are valid
    end
  end
end
```

#### Integration Tests

**File**: `test/ash_reports_demo/integration/json_dataset_loading_test.exs`

```elixir
defmodule AshReportsDemo.Integration.JsonDatasetLoadingTest do
  use AshReportsDemo.DataCase

  alias AshReportsDemo.DataGenerator

  @small_dataset_path Path.join([
    Application.app_dir(:ash_reports_demo, "priv"),
    "demo_data",
    "small.json"
  ])

  test "loads small dataset from JSON file" do
    # Clear existing data
    AshReportsDemo.EtsTables.clear_all_data()

    # Load dataset
    assert {:ok, :small} = DataGenerator.load_dataset_from_json(@small_dataset_path)

    # Verify data is accessible via Ash
    assert {:ok, customers} = Ash.read(Customer)
    assert length(customers) > 0

    # Verify charts can query data
    assert {:ok, chart_data} = AshReportsDemo.ChartData.fetch_customer_status_data()
    assert length(chart_data) > 0
  end

  test "validates data integrity after loading" do
    # Test referential integrity validation
  end
end
```

### Step 7: Performance Optimization (1-2 hours)

#### Benchmark Current vs New Approach

```elixir
# test/ash_reports_demo/benchmarks/data_loading_benchmark.exs
Benchee.run(
  %{
    "manual_ets_insertion" => fn ->
      # Current approach
    end,
    "ash_bulk_create" => fn ->
      # New approach
    end
  },
  time: 10,
  memory_time: 2
)
```

#### Expected Performance Characteristics

- **Small dataset (25 customers)**: Similar or slightly slower (Ash overhead)
- **Medium dataset (100 customers)**: Comparable performance
- **Large dataset (1000 customers)**: Better memory usage, similar time
- **Huge dataset (10000 customers)**: Significantly better memory management

---

## Success Criteria

### Functional Requirements

1. All pre-generated JSON datasets load successfully without errors
2. Charts display data correctly after loading from JSON
3. CSV exports work properly for all resources
4. `Ash.read!()` returns properly structured resource structs
5. Data Summary page shows correct counts
6. Referential integrity maintained across all relationships

### Non-Functional Requirements

1. Loading performance remains acceptable:
   - Small dataset: < 5 seconds
   - Medium dataset: < 15 seconds
   - Large dataset: < 60 seconds
   - Huge dataset: < 5 minutes
2. Memory usage remains reasonable (no OOM errors)
3. Error messages are clear and actionable
4. Code is maintainable and well-documented

### Validation Tests

```elixir
# Run these after implementation
mix test test/ash_reports_demo/data_generator_ash_loading_test.exs
mix test test/ash_reports_demo/integration/json_dataset_loading_test.exs

# Verify charts work
iex> AshReportsDemo.DataGenerator.load_dataset_from_json("priv/demo_data/small.json")
iex> AshReportsDemo.ChartData.fetch_customer_status_data()
{:ok, [%{category: "active", value: 18}, ...]}

# Verify Ash queries work
iex> Ash.read!(AshReportsDemo.Customer, domain: AshReportsDemo.Domain)
[%AshReportsDemo.Customer{...}, ...]
```

---

## Rollback Plan

If the new approach causes issues:

1. Keep the old `convert_json_to_dataset/1` implementation as `convert_json_to_dataset_legacy/1`
2. Add a feature flag to switch between implementations:
   ```elixir
   @use_ash_bulk_create Application.compile_env(:ash_reports_demo, :use_ash_bulk_create, true)
   ```
3. Revert by setting `config :ash_reports_demo, use_ash_bulk_create: false`

---

## Risks and Mitigations

### Risk 1: Performance Degradation
**Likelihood**: Medium
**Impact**: Medium
**Mitigation**:
- Benchmark before and after
- Tune batch_size parameter
- Consider using `max_concurrency` for large datasets

### Risk 2: Ash Validation Failures
**Likelihood**: High
**Impact**: High
**Mitigation**:
- Add comprehensive field transformation tests
- Use `assume_casted?: false` to let Ash handle validation
- Add special handling for calculated fields (skip them)

### Risk 3: Breaking Existing Functionality
**Likelihood**: Medium
**Impact**: High
**Mitigation**:
- Comprehensive integration tests before merging
- Test all charts and CSV exports
- Keep legacy implementation as fallback

### Risk 4: Memory Issues with Large Datasets
**Likelihood**: Low
**Impact**: High
**Mitigation**:
- Use `return_records?: false` to avoid memory bloat
- Process in smaller batches if needed
- Monitor memory usage during testing

---

## Questions for Discussion

1. Should we handle calculated fields (like `customer_health_score`) during loading?
   - **Recommendation**: Skip them - they're computed on read

2. What should be the default batch size?
   - **Recommendation**: Start with 100, tune based on benchmarks

3. Should we use transactions for the entire dataset or per-batch?
   - **Recommendation**: Per-batch (`transaction: :batch`) for better error recovery

4. How should we handle partial failures?
   - **Recommendation**: Log warnings but continue with `stop_on_error?: false` for non-critical data

5. Should we add retry logic for transient failures?
   - **Recommendation**: Yes, add simple retry with exponential backoff

---

## Timeline Estimate

| Phase | Task | Estimated Time |
|-------|------|----------------|
| 1 | Create new loading function | 1-2 hours |
| 2 | Create record transformation | 1 hour |
| 3 | Refactor convert_json_to_dataset | 2-3 hours |
| 4 | Add helper functions | 1 hour |
| 5 | Update load_dataset_from_json_file | 30 minutes |
| 6 | Write tests | 2-3 hours |
| 7 | Performance optimization | 1-2 hours |
| 8 | Documentation and cleanup | 1 hour |
| **TOTAL** | | **10-13.5 hours** |

---

## References

- [Ash Framework Bulk Actions Documentation](https://hexdocs.pm/ash/bulk-actions.html)
- [Ash.bulk_create/4 API Documentation](https://hexdocs.pm/ash/Ash.html#bulk_create/4)
- [Ash Create Actions Guide](https://hexdocs.pm/ash/create-actions.html)
- Current implementation: `lib/ash_reports_demo/data_generator.ex:940-981`
- Related issue: Charts showing "data cannot be empty" errors

---

## Next Steps

1. Review this plan with team
2. Get approval on approach
3. Create feature branch: `feature/ash-api-data-loading`
4. Implement in phases (test after each phase)
5. Run comprehensive test suite
6. Benchmark performance
7. Submit PR with detailed testing results

---

**Document Version**: 1.0
**Last Updated**: 2025-11-13
**Author**: Claude Code (AI Assistant)
