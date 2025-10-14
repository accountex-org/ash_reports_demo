# AshReports Demo UI Modernization Plan - Overview

## 📋 Executive Summary

This plan implements a comprehensive modernization of the AshReports Demo web UI to reflect the new AshReports architecture with GenStage streaming pipelines, multi-format renderers, and integrated chart generation. The existing data generation system remains unchanged.

**Current Status**: The demo has basic LiveView components using simplified direct data access, not leveraging the full pipeline architecture.

**Target Architecture**: Modern web UI using full AshReports pipeline (DataLoader → RenderContext → RenderPipeline → Multiple Renderers) with chart integration, streaming support, and real-time updates.

---

## Key Architectural Changes

### Pipeline Integration
- Replace direct Ash queries with `AshReports.Runner.run_report/4` pipeline API
- Leverage three-stage pipeline: Data Loading → Context Building → Rendering
- Implement proper error handling with stage context

### Multi-Format Support
- Add support for all renderer formats (HTML, HEEX, PDF, JSON)
- Implement format-specific download handlers
- Create unified viewer with format switching

### Chart Integration
- Integrate `AshReports.Charts` generation system
- Support all 5 chart types (bar, line, pie, area, scatter)
- Add interactive chart configuration UI
- Implement chart caching and optimization

### Streaming & Real-time
- Implement streaming report execution for large datasets
- Add WebSocket-based progress tracking
- Create real-time dashboard with telemetry integration
- Support pause/resume/cancel operations

---

## Phase Structure

### Phase 1: Core Pipeline Integration (1-2 weeks)
Replace existing LiveView components with pipeline-aware implementations
- **Files**: ~10 new files, 2 modified, 1-2 removed
- **Lines**: ~1,500-2,000 new lines of code

### Phase 2: Multi-Format Output Support (1-2 weeks)
Add support for all renderer formats with download capabilities
- **Files**: ~8 new files, 1 modified
- **Lines**: ~1,200-1,500 new lines of code

### Phase 3: Chart Integration (1-2 weeks)
Integrate AshReports chart generation system with demo UI
- **Files**: ~8 new files, 1 modified
- **Lines**: ~1,500-1,800 new lines of code

### Phase 4: Streaming Reports & Real-time Features (2-3 weeks)
Add streaming report support with progress tracking and WebSocket updates
- **Files**: ~10 new files
- **Lines**: ~2,000-2,500 new lines of code

### Phase 5: Advanced Features & Polish (1-2 weeks)
Add advanced UI features and production polish
- **Files**: ~6 new files, multiple enhancements
- **Lines**: ~1,500-2,000 new lines of code

### Phase 6: Testing & Documentation (1 week)
Comprehensive testing and documentation
- **Files**: ~20 test files, documentation updates
- **Lines**: ~2,000-2,500 lines of test code

---

## Success Criteria

### Functional Requirements
- [ ] All 4 existing reports execute via pipeline (customer_summary, product_inventory, invoice_details, financial_summary)
- [ ] All 4 output formats supported (HTML, PDF, JSON, HEEX)
- [ ] All 5 chart types integrated (bar, line, pie, area, scatter)
- [ ] Streaming works for reports with 10K+ records
- [ ] Progress tracking displays for long-running reports
- [ ] Error handling shows pipeline stage context
- [ ] Chart generation caching works correctly

### Performance Targets
- [ ] Report execution latency <2s for small reports (cached)
- [ ] Chart generation <500ms for standard sizes
- [ ] Streaming throughput >1000 records/second
- [ ] Memory usage <1.5x baseline for streaming reports
- [ ] WebSocket latency <100ms for progress updates

### User Experience
- [ ] Responsive design works on mobile devices
- [ ] Dark mode available for all components
- [ ] Keyboard shortcuts functional
- [ ] Error messages clear and actionable
- [ ] Loading states for all async operations

### Code Quality
- [ ] 80%+ test coverage for new components
- [ ] All tests passing
- [ ] No compilation warnings
- [ ] Credo checks passing
- [ ] Documentation complete for all public APIs

---

## Architecture Diagrams

### New Data Flow

```
User Request (LiveView)
    ↓
PipelineClient.run_report/4
    ↓
AshReports.Runner.run_report/4
    ↓
┌─────────────────────────────────────┐
│ Stage 1: Data Loading               │
│ - AshReports.DataLoader             │
│ - QueryBuilder → Executor           │
│ - VariableState (GenServer)         │
│ - GroupProcessor                    │
└──────────┬──────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│ Stage 2: Context Building           │
│ - AshReports.RenderContext          │
│ - Merge data + config               │
└──────────┬──────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│ Stage 3: Rendering                  │
│ - AshReports.RenderPipeline         │
│   1. Initialization                 │
│   2. Layout Calculation             │
│   3. Data Processing                │
│   4. Element Rendering              │
│   5. Assembly                       │
│   6. Finalization                   │
│ - Format-specific Renderer          │
│   (HTML/PDF/JSON/HEEX)              │
└──────────┬──────────────────────────┘
           ↓
Result {content, metadata, format}
    ↓
ResultHandler.process/1
    ↓
Display in LiveView
```

### Chart Integration Flow

```
User Selects Chart Parameters
    ↓
ChartConfigForm (LiveView)
    ↓
ChartDataExtractor.extract/2
    ↓
AshReports.Charts.generate/3
    ↓
┌─────────────────────────────────────┐
│ Chart Generation Pipeline           │
│ 1. Normalize config                 │
│ 2. Apply theme                      │
│ 3. Check cache                      │
│ 4. Registry.get(chart_type)         │
│ 5. Renderer.render/3                │
│ 6. SVG optimization                 │
│ 7. Cache result                     │
└──────────┬──────────────────────────┘
           ↓
SVG String
    ↓
ChartViewer Component
    ↓
Display in Browser
```

### Streaming Report Flow

```
User Clicks "Run Large Report"
    ↓
StreamingRunner.start/3
    ↓
AshReports.Runner.run_report/4 (streaming: true)
    ↓
┌─────────────────────────────────────┐
│ GenStage Streaming Pipeline         │
│                                     │
│ Producer → ProducerConsumer → Consumer
│     ↓            ↓            ↓
│  Chunks    Transforms    Aggregates
│     ↓            ↓            ↓
│ Progress Events (Telemetry)         │
└──────────┬──────────────────────────┘
           ↓
ProgressTracker GenServer
    ↓
Phoenix.Channel Broadcast
    ↓
LiveView Progress Component
    ↓
Real-time Progress Bar Updates
```

---

## Risk Mitigation

### Technical Risks
1. **Pipeline Integration Complexity**: Start with Phase 1 to establish patterns
2. **Streaming Performance**: Leverage existing GenStage implementation from AshReports
3. **Chart Rendering**: Use proven Contex library with extensive test coverage
4. **WebSocket Stability**: Implement heartbeat and reconnection logic

### Migration Strategy
1. **Incremental Replacement**: Replace one LiveView at a time
2. **Feature Flags**: Add config to toggle between old/new UI
3. **Parallel Development**: Keep existing UI functional during development
4. **Gradual Rollout**: Deploy phases incrementally
5. **Rollback Plan**: Keep old components until new system is validated

---

## Project Timeline

**Total Estimated Duration**: 8-12 weeks (2-3 weeks per phase)

| Phase | Duration | Start | Dependencies |
|-------|----------|-------|--------------|
| Phase 1: Core Pipeline | 1-2 weeks | Week 1 | None |
| Phase 2: Multi-Format | 1-2 weeks | Week 2-3 | Phase 1 |
| Phase 3: Chart Integration | 1-2 weeks | Week 4-5 | Phase 1, 2 |
| Phase 4: Streaming & Real-time | 2-3 weeks | Week 6-8 | Phase 1, 2, 3 |
| Phase 5: Advanced Features | 1-2 weeks | Week 9-10 | All previous |
| Phase 6: Testing & Documentation | 1 week | Week 11 | All previous |

---

## Team Requirements

**Recommended Team**: 1-2 developers with Elixir/Phoenix/LiveView expertise

### Skills Required
- Strong Elixir/Phoenix/LiveView experience
- Understanding of GenStage/streaming architectures
- Front-end development (HTML/CSS/JavaScript)
- Experience with WebSocket/real-time systems
- Testing expertise (ExUnit, integration testing)

### Optional Skills
- Chart.js or similar visualization library experience
- Telemetry/metrics systems
- Performance optimization

---

## Code Metrics Summary

### New Code Estimate
- **Total Lines**: ~6,000-8,000 lines of production code
- **Test Lines**: ~2,000-2,500 lines of test code
- **New Files**: ~50-60 files
- **Modified Files**: ~5-10 files
- **Removed Files**: ~2 files

### File Structure
```
lib/ash_reports_demo_web/
├── reports/ (7 new modules)
├── channels/ (1 new module)
├── controllers/ (2 new modules)
├── components/ (11 new modules)
└── live/ (15 new modules)

test/ash_reports_demo_web/
├── live/ (8 test files)
├── components/ (5 test files)
├── integration/ (5 test files)
└── channels/ (2 test files)
```

---

## Dependencies

### Existing Infrastructure
- ✅ AshReports library with complete pipeline (Stages 1-3)
- ✅ GenStage streaming implementation
- ✅ Chart generation system (Contex)
- ✅ Multi-format renderers (HTML, PDF, JSON, HEEX)
- ✅ Data generation system (keep as-is)

### New Dependencies
- Phoenix.Channel (already available)
- Phoenix.PubSub (already available)
- Alpine.js or LiveView hooks (for interactivity)
- Optional: Chart.js (for interactive charts)

---

## Next Steps

1. **Review and Approval**: Stakeholder review of this plan
2. **Environment Setup**: Ensure all dependencies are available
3. **Phase 1 Kickoff**: Start with core pipeline integration
4. **Weekly Progress Reviews**: Track progress against success criteria
5. **Continuous Testing**: Test each phase before moving to next
6. **Documentation**: Keep documentation updated throughout

---

## Phase Details

Each phase is documented in detail in separate files:

- [Phase 1: Core Pipeline Integration](./phase1_core_pipeline.md)
- [Phase 2: Multi-Format Output Support](./phase2_multi_format.md)
- [Phase 3: Chart Integration](./phase3_chart_integration.md)
- [Phase 4: Streaming & Real-time Features](./phase4_streaming_realtime.md)
- [Phase 5: Advanced Features & Polish](./phase5_advanced_features.md)
- [Phase 6: Testing & Documentation](./phase6_testing_documentation.md)

---

**Document Version**: 1.0
**Last Updated**: 2025-10-14
**Status**: Ready for Implementation
