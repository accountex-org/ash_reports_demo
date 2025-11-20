# Feature: Multi-Tenancy for Per-User Dataset Isolation

**Status**: In Progress
**Branch**: `feature/multi-tenancy-datasets`
**Date**: 2025-11-20

## Problem Statement

AshReportsDemo currently maintains a single global dataset that all users share. When one user switches datasets (small/medium/large/huge) via the DataSummaryComponent, it loads the selected dataset into ETS tables, affecting all other concurrent users. This creates a poor multi-user experience and prevents independent dataset exploration.

### Current Architecture Issues

1. **Global Dataset State**: `DataGenerator` GenServer maintains a single `current_dataset` that all users share
2. **Dataset Switching**: Calling `generate_sample_data(:medium)` clears all ETS tables and loads the new dataset for everyone
3. **No User Isolation**: All Ash queries hit the same ETS tables with no tenant filtering
4. **Confusing UX**: User A selects "small" dataset, User B sees their large dataset disappear

### Impact

- Users cannot independently explore different dataset sizes
- Concurrent usage causes unpredictable data disappearance
- Cannot demonstrate multi-user scenarios
- Real-world application pattern (tenant isolation) not demonstrated

## Solution Overview

Implement Ash's attribute-based multitenancy to load ALL datasets (small, medium, large, huge) into ETS simultaneously at startup, with each record tagged with a `dataset_id` attribute. User sessions select which dataset to view via tenant assignment, and all Ash queries automatically filter by the selected dataset.

### Design Decisions

1. **Multitenancy Strategy**: Use Ash's `:attribute` strategy (simplest, works with ETS data layer)
2. **Tenant Identifier**: String like `"small"`, `"medium"`, `"large"`, `"huge"`
3. **All Data Loaded**: Load all 4 datasets into ETS at startup (no switching required)
4. **Session-Based Selection**: Store user's dataset choice in Phoenix session
5. **Ash.ToTenant Protocol**: Allow passing atoms that convert to string dataset_id

### Benefits

- **User Isolation**: Each user views their selected dataset independently
- **Instant Switching**: No data loading when switching - just change tenant filter
- **Concurrent Usage**: Multiple users can view different datasets simultaneously
- **Realistic Pattern**: Demonstrates proper multi-tenant application architecture

## Implementation Plan

### Step 1: Add dataset_id Attribute to All Resources ⬜

Add multitenancy configuration to all 12 resources:
- [ ] CustomerType
- [ ] ProductCategory
- [ ] Customer
- [ ] CustomerAddress
- [ ] Product
- [ ] Inventory
- [ ] Invoice
- [ ] InvoiceLineItem
- [ ] SessionMetrics
- [ ] SessionSnapshot
- [ ] TelemetryEvent
- [ ] TelemetryMetric

### Step 2: Update DataGenerator for Multi-Dataset Loading ⬜

- [ ] Modify `load_dataset_from_json_file/1` to accept dataset_id parameter
- [ ] Update `load_records_via_ash/3` to set dataset_id on each record
- [ ] Modify initialization to load ALL available JSON datasets at startup
- [ ] Update `get_dataset_counts/1` to return counts for specific dataset

### Step 3: Implement Session-Based Tenant Assignment ⬜

- [ ] Create `TenantHook` LiveView hook
- [ ] Update router to use live_session with hook
- [ ] Ensure session persistence of dataset choice

### Step 4: Update DataSummaryComponent ⬜

- [ ] Remove data loading on dataset switch
- [ ] Update tenant in socket assigns
- [ ] Refresh counts from metadata

### Step 5: Update All Ash Queries to Use Tenant ⬜

- [ ] Update data_summary_component.ex CSV generation queries
- [ ] Update reports and charts to use tenant
- [ ] Search all `Ash.read`, `Ash.get` calls

### Step 6: Testing ⬜

- [ ] Add unit tests for tenant isolation
- [ ] Add integration tests for multi-user scenarios
- [ ] Manual testing with multiple browser sessions

### Step 7: Documentation ⬜

- [ ] Create summary document in notes/summaries

## Technical Details

### Resource Multitenancy Configuration

Each resource needs:

```elixir
multitenancy do
  strategy :attribute
  attribute :dataset_id
end

attributes do
  attribute :dataset_id, :string do
    allow_nil? false
    writable? true
  end
end
```

### Memory Considerations

With all 4 datasets loaded simultaneously:
- Total records: ~906,000 records
- Estimated ETS memory: 1-2 GB

### Files to Modify

- `lib/ash_reports_demo/resources/*.ex` - All 12 resources
- `lib/ash_reports_demo/data_generator.ex` - Multi-dataset loading
- `lib/ash_reports_demo_web/router.ex` - TenantHook
- `lib/ash_reports_demo_web/components/data_summary_component.ex` - Dataset switching
- `priv/demo_data/*.json` - Regenerate with dataset_id

## Success Criteria

- [ ] All resources have multitenancy configured
- [ ] All datasets load at startup with dataset_id
- [ ] Users can independently select datasets
- [ ] Dataset switching is instant
- [ ] Charts and reports filter by tenant

## Notes

- Start with core resources (CustomerType, ProductCategory) before dependent ones
- Test multitenancy works with ETS data layer
- Consider making huge dataset optional to reduce memory
