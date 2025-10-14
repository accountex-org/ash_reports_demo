# AshReports Demo UI Modernization - Planning Documentation

This directory contains comprehensive planning documentation for modernizing the AshReports Demo web interface to reflect the new AshReports architecture.

## Document Structure

### Overview
- **[UI Modernization Overview](./ui_modernization_overview.md)** - Executive summary, architecture, timeline, and success criteria

### Phase Documents

1. **[Phase 1: Core Pipeline Integration](./phase1_core_pipeline.md)** (1-2 weeks)
   - Pipeline client wrapper
   - Result handling
   - Error display components
   - Universal report viewer
   - Parameter forms
   - Testing infrastructure

2. **[Phase 2: Multi-Format Output Support](./phase2_multi_format.md)** (1-2 weeks)
   - HTML renderer integration
   - PDF download handler
   - JSON API endpoints
   - HEEX live components
   - Format selector UI
   - Export menu

3. **[Phase 3: Chart Integration](./phase3_chart_integration.md)** (1-2 weeks)
   - Chart viewer component
   - Chart configuration UI
   - Chart gallery
   - Report-chart integration
   - Chart data extraction
   - Lazy loading and caching

4. **[Phase 4: Streaming Reports & Real-time Features](./phase4_streaming_realtime.md)** (2-3 weeks)
   - Streaming report runner
   - Progress tracking system
   - WebSocket channels
   - Progress bar component
   - Streaming viewer
   - Performance dashboard

5. **[Phase 5: Advanced Features & Polish](./phase5_advanced_features.md)** (1-2 weeks)
   - Report library
   - Report scheduling (optional)
   - Dark mode support
   - Responsive design
   - Keyboard shortcuts
   - In-app documentation

6. **[Phase 6: Testing & Documentation](./phase6_testing_documentation.md)** (1 week)
   - Comprehensive test suite
   - LiveView tests
   - Component tests
   - Integration tests
   - Performance tests
   - User and developer guides

## Quick Reference

### Total Timeline
**8-12 weeks** across 6 phases

### Team Requirements
- 1-2 developers with Elixir/Phoenix/LiveView expertise
- Skills: Elixir, Phoenix, LiveView, GenStage, WebSocket, Front-end (HTML/CSS/JS)

### Code Estimates
- **New Code**: ~6,000-8,000 lines of production code
- **Test Code**: ~2,500 lines of test code
- **New Files**: ~50-60 files
- **Modified Files**: ~5-10 files

### Key Deliverables by Phase

| Phase | Key Deliverables | Files | Lines |
|-------|-----------------|-------|-------|
| Phase 1 | Pipeline integration, Report viewer | ~10 | ~1,500-2,000 |
| Phase 2 | Multi-format support, Downloads | ~8 | ~1,200-1,500 |
| Phase 3 | Chart integration, Gallery | ~8 | ~1,500-1,800 |
| Phase 4 | Streaming, Progress tracking | ~10 | ~2,000-2,500 |
| Phase 5 | UI polish, Dark mode | ~6 | ~1,500-2,000 |
| Phase 6 | Testing, Documentation | ~20 | ~2,500 |

### Success Criteria

#### Functional Requirements
- ✓ All 4 existing reports work through pipeline
- ✓ All 4 output formats supported (HTML, PDF, JSON, HEEX)
- ✓ All 5 chart types integrated
- ✓ Streaming works for 10K+ records
- ✓ Real-time progress tracking
- ✓ Comprehensive error handling

#### Performance Targets
- Report execution: <2s (cached), <10s (fresh)
- Chart generation: <500ms
- Streaming throughput: >1000 records/second
- Memory usage: <1.5x baseline
- WebSocket latency: <100ms

#### Quality Metrics
- Test coverage: ≥80%
- Zero compilation warnings
- Credo checks passing
- Complete documentation

## Reading Order

### For Project Managers
1. Start with [Overview](./ui_modernization_overview.md)
2. Review timeline and resource requirements
3. Skim each phase document for deliverables

### For Developers
1. Read [Overview](./ui_modernization_overview.md) for context
2. Deep dive into [Phase 1](./phase1_core_pipeline.md) to understand foundation
3. Read subsequent phases in order
4. Reference architecture diagrams throughout

### For Stakeholders
1. Read [Overview](./ui_modernization_overview.md)
2. Focus on Success Criteria section
3. Review timeline and team requirements

## Dependencies

### External Dependencies
- AshReports library (Stages 1-3 completed)
- Phoenix.LiveView
- Phoenix.Channel
- Phoenix.PubSub
- Contex (for charts)
- Optional: Oban (for scheduling)

### Prerequisites
- Phase 1 is the foundation - must be completed first
- Phases 2-3 can be partially parallelized
- Phase 4 depends on Phase 1
- Phase 5 depends on all previous phases
- Phase 6 depends on all previous phases

## Key Architectural Decisions

### Pipeline Architecture
The new UI uses the complete AshReports pipeline:
```
DataLoader → RenderContext → RenderPipeline → Format Renderers
```

### Streaming Architecture
Large reports use GenStage streaming with real-time progress:
```
Producer → ProducerConsumer → Consumer → WebSocket → LiveView
```

### Chart Integration
Charts generated server-side with SVG output:
```
Report Data → ChartDataExtractor → AshReports.Charts → SVG → Browser
```

## Migration Strategy

1. **Incremental Replacement**: Replace one component at a time
2. **Parallel Development**: Keep existing UI functional
3. **Feature Flags**: Add config toggles for new vs old
4. **Gradual Rollout**: Deploy phases incrementally
5. **Rollback Plan**: Maintain old components until validated

## Risk Mitigation

### Technical Risks
- **Pipeline Complexity**: Start with Phase 1 to establish patterns
- **Streaming Performance**: Leverage AshReports GenStage implementation
- **Chart Rendering**: Use proven Contex library
- **WebSocket Stability**: Implement heartbeat and reconnection

### Mitigation Strategies
- Comprehensive testing at each phase
- Performance benchmarking throughout
- Regular code reviews
- Documentation as you build

## Getting Started

To begin implementation:

1. **Setup**: Ensure all dependencies are installed
2. **Phase 1**: Start with core pipeline integration
3. **Testing**: Write tests as you build (TDD encouraged)
4. **Documentation**: Update docs alongside code
5. **Review**: Regular code reviews and demos

## Questions?

For questions or clarifications about the planning documents:
1. Check the specific phase document for detailed information
2. Review the Overview document for high-level context
3. Consult the architecture diagrams for data flow
4. Refer to the AshReports library documentation

---

**Document Version**: 1.0
**Last Updated**: 2025-10-14
**Status**: Ready for Implementation
