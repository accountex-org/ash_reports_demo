# Refactor HEEX Renderer to Generate Proper HEEX Templates

**Status**: Planning
**Priority**: High
**Created**: 2025-11-05
**Assigned to**: Development Team

---

## Problem Statement

### Current Approach Limitations

The current HEEX renderer implementation (Phase 3.3) pre-renders everything into static HTML strings at generation time, which severely limits the benefits of using Phoenix LiveView:

1. **No LiveView Diffing**: The renderer uses `Enum.map` and `Enum.join` to concatenate HTML strings:
   ```elixir
   # Current approach in band_renderer.ex:101
   defp render_bands_without_grouping(bands, context) do
     bands
     |> Enum.map(fn band -> render_band(band, context) end)
     |> Enum.join("\n")
   end
   ```

2. **Static Data Interpolation**: All data is interpolated during template generation, not at render time:
   ```elixir
   # Current approach in band_renderer.ex:513-517
   """
   <span class="field-element" data-field="#{element.name}" style="#{style}">
     #{formatted_value}
   </span>
   """
   ```

3. **No Phoenix Assigns**: Cannot use `@variable` syntax or benefit from assign tracking

4. **No Reactivity**: Cannot update reports in real-time without full re-generation

5. **Large Output Size**: Generates complete HTML strings for all data, even for large datasets

6. **No Component Reusability**: While Phoenix components are defined in `components.ex`, they're not actually used in the generated templates

### What We Want

Generate **true HEEX template code** that Phoenix evaluates at runtime:

```heex
<.report_container report={@report} class="ash-report">
  <.report_header title={@report.title} metadata={@metadata} />

  <.report_content>
    <.band :for={band <- @bands} band={band} records={@records}>
      <.element :for={element <- band.elements} element={element} />
    </.band>
  </report_content>
</.report_container>
```

This approach enables:
- **Efficient LiveView updates** via differential rendering
- **Dynamic data binding** with assigns
- **Reactive updates** when data changes
- **Smaller initial payload** with lazy evaluation
- **Component composition** and reusability

---

## Solution Overview

### Architecture Changes

The refactor involves **separating template generation from data rendering**:

```
Current:   Report Definition + Data → [BandRenderer] → Complete HTML String
Proposed:  Report Definition → [TemplateGenerator] → HEEX Template String
           HEEX Template + Data → [Phoenix.Component] → Rendered HTML
```

### Two-Phase Rendering

#### Phase 1: Template Generation (Build-Time or Cache)
Generate a HEEX template string from the report definition:
```elixir
{:ok, template_string} = HeexRenderer.generate_template(report_definition)
# Returns: "<.report_container report={@report}>...</.report_container>"
```

#### Phase 2: Template Evaluation (Runtime)
Phoenix evaluates the template with assigns:
```elixir
assigns = %{
  report: report_definition,
  records: data_records,
  variables: computed_variables,
  groups: group_data
}
Phoenix.Component.eval_heex(template_string, assigns)
```

### Key Design Decisions

1. **Template Generation is Structural**: Based only on report definition (bands, elements, layout)
2. **Data Binding is Dynamic**: Via assigns at evaluation time
3. **Backward Compatibility**: Maintain existing Renderer behavior interface
4. **Component Library**: Leverage existing `Components` module
5. **Caching Strategy**: Cache generated templates per report definition

---

## Technical Analysis

### Files to Modify

#### Primary Files
1. **`/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/heex_renderer/heex_renderer.ex`**
   - Add `generate_template/1` function
   - Modify `render_with_context/2` to use template + assigns approach
   - Keep backward compatibility with existing API

2. **`/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/heex_renderer/band_renderer.ex`**
   - Refactor `render_report_bands/1` to generate template strings
   - Change from `Enum.map |> Enum.join` to HEEX comprehensions
   - Separate structural rendering from data interpolation

3. **`/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/heex_renderer/components.ex`**
   - Components already defined correctly
   - May need helper functions for component invocation strings

#### Supporting Files
4. **`/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/render_context.ex`**
   - Already well-structured for assigns
   - May need additional helpers for template context

5. **New File: `/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/heex_renderer/template_generator.ex`**
   - Core logic for converting report definition to HEEX template
   - Template caching mechanism
   - Template optimization utilities

### Data Structures

#### Template Context (New)
```elixir
%TemplateContext{
  report: Report.t(),           # Report definition
  bands: [Band.t()],           # Band definitions
  elements: [Element.t()],     # Element definitions
  has_groups: boolean(),       # Whether report uses grouping
  template_cache_key: String.t()
}
```

#### Render Assigns (Extracted from RenderContext)
```elixir
%{
  # Report structure (rarely changes)
  report: Report.t(),
  bands: [Band.t()],

  # Data (changes frequently)
  records: [map()],
  current_record: map() | nil,

  # Computed values
  variables: %{atom() => term()},
  groups: %{term() => map()},

  # Metadata
  metadata: map(),
  locale: String.t(),
  text_direction: String.t()
}
```

### Key Technical Challenges

#### 1. Converting String Concatenation to HEEX Comprehensions

**Current Pattern**:
```elixir
bands
|> Enum.map(fn band -> render_band(band, context) end)
|> Enum.join("\n")
```

**Proposed Pattern**:
```elixir
"""
<%= for band <- @bands do %>
  <.band band={band} records={@records}>
    <%= for element <- band.elements do %>
      <.element element={element} record={@current_record} />
    <% end %>
  </.band>
<% end %>
"""
```

#### 2. Data Access Transformation

**Current**: Direct interpolation with formatted values
```elixir
value = get_field_value(element, context)
formatted_value = format_value(value, element)
"<span>#{formatted_value}</span>"
```

**Proposed**: Pass data via assigns, format at component level
```elixir
# In template
"<.field_element element={element} record={@current_record} />"

# In component
def field_element(assigns) do
  assigns = assign(assigns, :value, get_field_value(assigns.record, assigns.element))
  ~H"<span><%= format_value(@value, @element) %></span>"
end
```

#### 3. Nested Band Rendering

Current recursive approach works but needs to generate template syntax:

**Current**:
```elixir
defp render_nested_bands(%Band{bands: nested_bands}, context) do
  render_bands(nested_bands, context)
end
```

**Proposed**:
```elixir
defp generate_nested_bands_template(%Band{bands: nested_bands}) do
  """
  <%= if @band.bands do %>
    <%= for nested_band <- @band.bands do %>
      <.band band={nested_band} records={@records}>
        <%= render_band_content(nested_band) %>
      </.band>
    <% end %>
  <% end %>
  """
end
```

#### 4. Grouping Logic

The current grouping implementation (lines 860-942 in band_renderer.ex) does complex data processing. This needs to be **moved to data preparation phase**:

**Current**: BandRenderer handles grouping during rendering
**Proposed**: DataLoader/RenderContext prepares grouped data structure, template iterates over it

```elixir
# Data preparation (in DataLoader or RenderContext)
grouped_records = [
  {group_values: %{region: "CA", tier: "Gold"}, records: [...]},
  {group_values: %{region: "CA", tier: "Silver"}, records: [...]},
  {group_values: %{region: "NY", tier: "Gold"}, records: [...]}
]

# Template (generated)
"""
<%= for group <- @grouped_records do %>
  <.group_header values={group.group_values} />
  <%= for record <- group.records do %>
    <.detail_record record={record} />
  <% end %>
  <.group_footer aggregates={group.aggregates} />
<% end %>
"""
```

#### 5. Variable Resolution

Current approach resolves variables during rendering. With HEEX templates, variables must be in assigns:

**Strategy**:
- Pre-calculate all variables in RenderContext
- Include in assigns map
- Reference directly in template: `@variables.total_count`

#### 6. Chart Integration

Charts are already handled well (lines 539-717 in heex_renderer.ex). The chart components can remain as LiveComponents and be included in the generated template:

```heex
<%= if @supports_charts do %>
  <%= for chart <- @charts do %>
    <.live_component
      module={AshReports.LiveView.ChartLiveComponent}
      id={chart.id}
      chart_config={chart.config}
    />
  <% end %>
<% end %>
```

---

## Implementation Plan

### Phase 1: Foundation (Week 1)

#### Task 1.1: Create TemplateGenerator Module
- [ ] Create `template_generator.ex` with basic structure
- [ ] Implement `generate_template/1` for simple reports
- [ ] Add template caching mechanism
- [ ] Write unit tests for template generation

**Files**: New file `template_generator.ex`

#### Task 1.2: Refactor Simple Band Rendering
- [ ] Create `generate_band_template/1` function
- [ ] Handle title, page_header, summary bands (non-repeating)
- [ ] Convert string concatenation to template strings
- [ ] Test with simple single-band reports

**Files**: `band_renderer.ex`

#### Task 1.3: Update HeexRenderer API
- [ ] Add `generate_template/1` public API
- [ ] Add `render_with_template/2` that takes template + assigns
- [ ] Keep `render_with_context/2` for backward compatibility
- [ ] Add integration tests

**Files**: `heex_renderer.ex`

### Phase 2: Detail Bands & Data Binding (Week 2)

#### Task 2.1: Detail Band Templates
- [ ] Generate template for detail bands with `:for` comprehensions
- [ ] Handle element iteration within bands
- [ ] Implement field value binding via assigns
- [ ] Test with multi-record reports

**Files**: `band_renderer.ex`, `template_generator.ex`

#### Task 2.2: Element Rendering in Templates
- [ ] Convert element rendering to component calls
- [ ] Generate correct component invocations with assigns
- [ ] Handle different element types (field, label, expression, etc.)
- [ ] Test element data binding

**Files**: `band_renderer.ex`, `components.ex`

#### Task 2.3: Variable Management
- [ ] Ensure all variables are pre-calculated in RenderContext
- [ ] Update assigns structure to include variables map
- [ ] Modify templates to reference `@variables.*`
- [ ] Test variable rendering and updates

**Files**: `render_context.ex`, `template_generator.ex`

### Phase 3: Grouping & Advanced Features (Week 3)

#### Task 3.1: Data Grouping Preparation
- [ ] Move grouping logic to RenderContext or DataLoader
- [ ] Create grouped data structure
- [ ] Include group aggregates in data structure
- [ ] Test grouping with various group levels

**Files**: `render_context.ex`, potentially `data_loader.ex`

#### Task 3.2: Group Band Templates
- [ ] Generate templates for group headers/footers
- [ ] Implement nested group iteration
- [ ] Handle group-scoped variables
- [ ] Test multi-level grouping

**Files**: `band_renderer.ex`, `template_generator.ex`

#### Task 3.3: Nested Bands
- [ ] Implement recursive template generation for nested bands
- [ ] Handle arbitrary nesting depth
- [ ] Test with complex nested structures

**Files**: `band_renderer.ex`, `template_generator.ex`

### Phase 4: Optimization & Testing (Week 4)

#### Task 4.1: Template Caching
- [ ] Implement template cache with ETS
- [ ] Cache based on report definition hash
- [ ] Add cache invalidation mechanism
- [ ] Measure performance improvements

**Files**: `template_generator.ex`, potentially new `template_cache.ex`

#### Task 4.2: Performance Testing
- [ ] Benchmark template generation vs old approach
- [ ] Measure LiveView update performance
- [ ] Test with large datasets (1000+ records)
- [ ] Optimize hot paths

**Files**: New test files

#### Task 4.3: Integration Testing
- [ ] Test all report types from demo app
- [ ] Verify backward compatibility
- [ ] Test LiveView real-time updates
- [ ] Test with different renderers (HTML, PDF)

**Files**: Test files in `ash_reports_demo`

#### Task 4.4: Documentation
- [ ] Update renderer documentation
- [ ] Add template generation guide
- [ ] Document migration path for existing reports
- [ ] Add examples and cookbook entries

**Files**: Module documentation, potentially new guides

---

## Success Criteria

### Functional Requirements
- ✅ Generate valid HEEX template strings from report definitions
- ✅ Templates use `:for` comprehensions for iteration
- ✅ Data is bound via assigns (`@record`, `@variables`, etc.)
- ✅ Phoenix components are properly invoked
- ✅ Backward compatibility with existing `render_with_context/2` API
- ✅ All existing reports in demo app render correctly
- ✅ Support for all band types (title, detail, group_header, etc.)
- ✅ Support for all element types (field, label, expression, etc.)
- ✅ Support for grouping (single and multi-level)
- ✅ Support for nested bands
- ✅ Chart integration works in generated templates

### Performance Requirements
- ✅ Template generation < 50ms for typical report
- ✅ LiveView updates < 100ms for data changes
- ✅ Memory usage reduced by 30%+ for large datasets
- ✅ Template caching provides 10x speedup on repeated renders

### Quality Requirements
- ✅ 90%+ test coverage for new code
- ✅ All existing tests pass
- ✅ No breaking changes to public API
- ✅ Documentation updated and accurate
- ✅ Code review approved by senior engineer

---

## Testing Strategy

### Unit Tests

1. **Template Generation**
   - Test template generation for each band type
   - Test element rendering in templates
   - Test grouping template generation
   - Test nested band templates
   - Test variable references in templates

2. **Component Invocation**
   - Test component syntax generation
   - Test assign passing to components
   - Test different element types

3. **Data Binding**
   - Test field value binding
   - Test variable binding
   - Test group aggregate binding

### Integration Tests

1. **Full Report Rendering**
   - Test complete report template generation
   - Test template evaluation with real data
   - Test with all demo reports

2. **LiveView Integration**
   - Test LiveView mount with generated templates
   - Test LiveView updates with data changes
   - Test real-time variable updates

3. **Backward Compatibility**
   - Test existing API still works
   - Test migration path from old to new approach

### Performance Tests

1. **Benchmarks**
   - Template generation time
   - Rendering time comparison (old vs new)
   - Memory usage comparison
   - Cache hit/miss rates

2. **Load Tests**
   - 10, 100, 1000, 10000 record datasets
   - Complex grouping scenarios
   - Nested band structures

---

## Risk Assessment

### High Risk
1. **Breaking Changes**: Accidental API changes
   - **Mitigation**: Maintain strict backward compatibility, comprehensive testing

2. **Performance Regression**: New approach slower than old
   - **Mitigation**: Benchmark early and often, optimize hot paths

### Medium Risk
3. **Complex Grouping Logic**: Moving grouping to data layer is complex
   - **Mitigation**: Incremental approach, start with simple cases

4. **Template Syntax Errors**: Generated templates may have syntax issues
   - **Mitigation**: Template validation, unit tests, syntax checking

### Low Risk
5. **Cache Invalidation**: Stale templates in cache
   - **Mitigation**: Hash-based cache keys, explicit invalidation API

6. **Component Library Changes**: Components may need updates
   - **Mitigation**: Components already well-designed, minimal changes needed

---

## Migration Path

### For Library Users

**No changes required** if using standard `render_with_context/2` API:
```elixir
# This continues to work unchanged
{:ok, result} = HeexRenderer.render_with_context(context)
```

**Optional optimization** for repeated renders:
```elixir
# Generate template once
{:ok, template} = HeexRenderer.generate_template(report)

# Use cached template for multiple renders
assigns = build_assigns(data1)
result1 = HeexRenderer.render_with_template(template, assigns)

assigns = build_assigns(data2)
result2 = HeexRenderer.render_with_template(template, assigns)
```

### For Library Developers

1. Update imports if using internal rendering functions
2. Review custom element types for assign compatibility
3. Update any direct `BandRenderer` usage

---

## Notes & Considerations

### Edge Cases

1. **Empty Data**: Templates must handle `@records = []`
2. **Nil Values**: Components must safely handle `nil` in assigns
3. **Missing Variables**: Template must handle undefined variables gracefully
4. **Deep Nesting**: Test with deeply nested band structures (5+ levels)
5. **Large Group Counts**: Test with 100+ groups

### Future Enhancements

1. **Template Streaming**: Stream template chunks for very large reports
2. **Partial Updates**: Update only changed sections in LiveView
3. **Template Compilation**: Compile templates to Erlang modules for max performance
4. **Template Validation**: Validate generated templates before caching
5. **Developer Tools**: Template inspector/debugger for development

### Alternative Approaches Considered

#### Approach A: Full Runtime Generation (Rejected)
Generate templates on every render. **Rejected** because:
- No performance benefit
- Defeats purpose of caching
- Still requires data separation

#### Approach B: Macro-Based Templates (Rejected)
Use Elixir macros to generate templates at compile time. **Rejected** because:
- Reports are dynamic, not known at compile time
- Overly complex
- Harder to debug

#### Approach C: Hybrid Approach (Selected)
Generate template strings at runtime, cache them, evaluate with Phoenix. **Selected** because:
- Balances flexibility and performance
- Leverages Phoenix's existing optimizations
- Enables LiveView benefits
- Clear separation of concerns

### Dependencies

- **Phoenix >= 1.7**: For component system
- **Phoenix.LiveView >= 0.20**: For LiveView features
- **Existing AshReports modules**: DataLoader, RenderContext, etc.

### Team Collaboration

- **Backend Team**: DataLoader grouping logic
- **Frontend Team**: LiveView integration testing
- **DevOps Team**: Performance monitoring setup

---

## Timeline

**Total Estimated Time**: 4 weeks

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Foundation | 1 week | None |
| Phase 2: Data Binding | 1 week | Phase 1 |
| Phase 3: Grouping | 1 week | Phase 2 |
| Phase 4: Testing | 1 week | Phase 3 |

**Milestones**:
- Week 1: Simple reports render with new approach
- Week 2: Detail bands and data binding working
- Week 3: Grouping and nested bands functional
- Week 4: Performance targets met, all tests pass

---

## References

### Code References
- `/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/heex_renderer/heex_renderer.ex` (lines 65-81: desired structure)
- `/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/heex_renderer/band_renderer.ex` (lines 98-102: current problematic pattern)
- `/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/heex_renderer/components.ex` (component library)
- `/home/pcharbon/code/ash_reports/lib/ash_reports/renderers/render_context.ex` (context structure)

### Documentation
- Phoenix.Component documentation
- Phoenix.LiveView documentation
- HEEx template syntax guide
- Elixir stream processing patterns

### Related Issues
- None yet - this is the initial planning document

---

**Document Version**: 1.0
**Last Updated**: 2025-11-05
**Next Review**: Start of Phase 1 implementation
