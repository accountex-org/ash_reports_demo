# Feature Planning Document: Region Name at Generation

## 1. Problem Statement

### Current Issues

**Data Integrity Gap**: Pre-generated JSON datasets stored in `priv/demo_data/` (small.json, medium.json, large.json, huge.json) contain customer records with `region_name` set to `nil`. This creates inconsistency where the data is incomplete until post-processing occurs.

**Performance Overhead**: After loading JSON datasets, a background task (`update_customer_regions_from_addresses/0` at lines 1742-1790 in `data_generator.ex`) must iterate through all customer records to populate `region_name` based on primary address state. For large datasets (10,000+ customers), this adds noticeable startup delay.

**Code Complexity**: The codebase maintains two separate code paths for region assignment:
1. `update_customer_regions/1` (lines 1714-1740) - Used during live data generation, iterates through customers with Ash queries
2. `update_customer_regions_from_addresses/0` (lines 1742-1790) - Used after JSON loading, uses direct ETS operations

Both paths use the same `classify_state_to_region/1` function (lines 1792-1819) but have different implementations for accessing and updating data.

**Maintenance Burden**: When region classification logic changes, the post-load update code must be maintained separately, increasing the chance of bugs and inconsistencies.

### Impact Analysis

- **User Experience**: Application startup includes a visible delay while regions are calculated (1-2 seconds for small datasets, 5-10+ seconds for large datasets)
- **Code Quality**: Duplicate logic violates DRY principle and increases maintenance burden
- **Data Quality**: Pre-generated datasets are incomplete and rely on post-processing
- **Testing**: Tests using pre-generated data may encounter timing issues if they run before background task completes

## 2. Solution Overview

### High-Level Approach

**Set region_name during customer creation** in the data generator, eliminating the need for post-load updates. The region classification logic will be invoked immediately when creating customer records, ensuring complete data from the start.

### Key Decisions

1. **Modify customer creation flow**: Update `create_addresses_for_customers/2` to set `region_name` on customers based on their primary address state
2. **Regenerate all JSON datasets**: Use `mix demo.generate_json` to create new dataset files with complete region_name values
3. **Remove post-load logic**: Delete `update_customer_regions_from_addresses/0` and its invocation after JSON loading
4. **Preserve live generation logic**: Keep `update_customer_regions/1` for live data generation scenarios (non-JSON)

### Benefits

- **Faster startup**: Eliminates 1-10+ seconds of post-processing time
- **Cleaner codebase**: Removes ~50 lines of duplicate logic
- **Better data integrity**: Pre-generated datasets are complete and ready to use
- **Simpler testing**: No timing issues with background tasks

## 3. Implementation Status

### ✅ Completed Steps

None yet - starting implementation

### 🔄 In Progress

Step 1: Create feature branch and setup

### ⏳ Pending Steps

- Step 2: Code cleanup (remove post-load update logic)
- Step 3: Verify existing generation logic
- Step 4: Regenerate small dataset (testing)
- Step 5: Test small dataset loading
- Step 6: Regenerate all datasets
- Step 7: Integration testing
- Step 8: Documentation and commit

## 4. Technical Details

### File Locations

**Primary Files to Modify**:
- `C:\code\ash_reports_demo\lib\ash_reports_demo\data_generator.ex` - Update customer creation and remove post-load logic
- `C:\code\ash_reports_demo\priv\demo_data\small.json` - Regenerate with region_name
- `C:\code\ash_reports_demo\priv\demo_data\medium.json` - Regenerate with region_name
- `C:\code\ash_reports_demo\priv\demo_data\large.json` - Regenerate with region_name

**Related Files** (no changes needed, but verify):
- `C:\code\ash_reports_demo\lib\ash_reports_demo\resources\customer.ex` - Customer resource with region_name attribute (lines 68-71)
- `C:\code\ash_reports_demo\lib\mix\tasks\demo.generate_json.ex` - Mix task to regenerate datasets

### Code Changes Needed

**1. Remove `update_customer_regions_from_addresses/0` (lines 1742-1790)**:
Delete this entire function - it's only used for post-JSON-load updates and will become obsolete.

**2. Remove invocation in `load_dataset_from_json_file/1` (lines 986-1012)**:
Delete lines 995-1000 which start the background task

**3. Verify region_name is set during generation**:
The `update_customer_regions/1` function (lines 1714-1740) is already called at line 1709 in `create_addresses_for_customers/2`. This ensures region_name is populated during live generation.

## 5. Success Criteria

### Measurable Outcomes

1. **Performance**: Application startup time reduced by 1-10+ seconds (depending on dataset size)
2. **Data Completeness**: 100% of customers in JSON datasets have non-nil `region_name` values
3. **Code Reduction**: ~50-60 lines of code removed (post-load update function and invocation)
4. **Verification**: All regions correctly classified according to `classify_state_to_region/1` logic

## 6. Notes/Considerations

### Edge Cases

**1. Customers Without Addresses**:
- Current code assumes all customers have at least one address
- The primary address is created first (line 1696: `primary: i == 1`)
- Already handled in `update_customer_regions/1` (line 1727: `if primary_address do`)

**2. Unknown Regions**:
- States not in classification map return "Unknown"
- This is acceptable for demo purposes

### Risks

**Low Risk**:
- ✅ Region classification logic already tested and working
- ✅ Customer creation flow already calls update_customer_regions/1
- ✅ JSON datasets can be regenerated if issues found
- ✅ Changes are additive (removing code, not changing behavior)

### Rollback Plan

If issues arise after implementation:
```bash
git revert HEAD  # Reverts the commit
mix phx.server   # Application uses old JSON files
```
