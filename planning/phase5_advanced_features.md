# Phase 5: Advanced Features & Polish

**Duration**: 1-2 weeks
**Goal**: Add advanced UI features and production polish
**Prerequisites**: Phase 1, 2, 3, and 4 completed

---

## Overview

Phase 5 adds the final layer of polish and advanced features to create a production-ready demo application. This includes report management features, user experience enhancements, responsive design, dark mode, keyboard shortcuts, and comprehensive in-app documentation.

**Key Deliverable**: Production-ready demo with polished UX and advanced features.

---

## Section 5.1: Report Management

### 5.1.1 Report Library Component

**File**: `lib/ash_reports_demo_web/live/report_live/library.ex`
**Estimated Lines**: ~220

#### Purpose
Comprehensive report browsing interface with categorization, search, and favorites.

#### Tasks
- [ ] Create `ReportLive.Library` LiveView
  ```elixir
  defmodule AshReportsDemoWeb.ReportLive.Library do
    use AshReportsDemoWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, load_library_state(socket)}
    end

    def handle_event("search", %{"query" => query}, socket) do
      {:noreply, search_reports(socket, query)}
    end

    def handle_event("filter_category", %{"category" => category}, socket) do
      {:noreply, filter_by_category(socket, category)}
    end
  end
  ```

- [ ] Categorized report listing
  ```heex
  <div class="report-library">
    <aside class="category-sidebar">
      <h3>Categories</h3>
      <nav>
        <a
          :for={category <- @categories}
          phx-click="filter_category"
          phx-value-category={category.name}
          class={if @current_category == category.name, do: "active"}
        >
          <.icon name={category.icon} />
          <%= category.name %>
          <span class="count"><%= category.report_count %></span>
        </a>
      </nav>
    </aside>

    <main class="report-grid">
      <div :for={report <- @filtered_reports} class="report-card">
        <!-- Report card content -->
      </div>
    </main>
  </div>
  ```

- [ ] Organize reports by category
  - Financial Reports
  - Customer Analytics
  - Inventory Reports
  - Sales Reports
  - Custom category support

- [ ] Search functionality with filters
  ```elixir
  defp search_reports(socket, query) do
    filtered = Enum.filter(socket.assigns.reports, fn report ->
      String.contains?(
        String.downcase(report.title <> " " <> report.description),
        String.downcase(query)
      )
    end)

    assign(socket, filtered_reports: filtered, search_query: query)
  end
  ```

- [ ] Favorite reports
  ```elixir
  def handle_event("toggle_favorite", %{"report" => report_name}, socket) do
    favorites = toggle_favorite(socket.assigns.favorites, report_name)

    # Persist to user preferences
    save_favorites(socket.assigns.current_user, favorites)

    {:noreply, assign(socket, favorites: favorites)}
  end
  ```

- [ ] Recent reports history
  ```heex
  <section class="recent-reports">
    <h3>Recent Reports</h3>
    <div class="recent-list">
      <div :for={report <- @recent_reports} class="recent-item">
        <.link navigate={~p"/reports/#{report.name}"}>
          <%= report.title %>
        </.link>
        <span class="timestamp">
          <%= format_relative_time(report.accessed_at) %>
        </span>
      </div>
    </div>
  </section>
  ```

- [ ] Report execution history
  - Track report runs
  - Parameters used
  - Execution time
  - Result download links
  - Success/failure status

---

### 5.1.2 Report Scheduling (Optional)

**File**: `lib/ash_reports_demo_web/live/schedule_live/index.ex`
**Estimated Lines**: ~330

#### Purpose
Schedule recurring report generation with Oban (if available).

#### Tasks
- [ ] Create `ScheduleLive.Index` LiveView (if Oban available)
  ```elixir
  defmodule AshReportsDemoWeb.ScheduleLive.Index do
    use AshReportsDemoWeb, :live_view

    # Only compiled if Oban is available
    if Code.ensure_loaded?(Oban) do
      def mount(_params, _session, socket) do
        {:ok, load_schedules(socket)}
      end
    end
  end
  ```

- [ ] Schedule recurring reports
  ```elixir
  defmodule AshReportsDemo.Workers.ScheduledReportWorker do
    use Oban.Worker, queue: :reports

    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) do
      %{
        "report_name" => report_name,
        "params" => params,
        "format" => format,
        "recipients" => recipients
      } = args

      # Generate and deliver report
      with {:ok, result} <- generate_report(report_name, params, format),
           :ok <- deliver_report(result, recipients) do
        :ok
      end
    end
  end
  ```

- [ ] Email delivery integration
  - SMTP configuration
  - Email templates
  - Attachment handling
  - Delivery tracking

- [ ] Cron-style scheduling
  ```heex
  <form phx-submit="create_schedule">
    <.input
      field={@form[:report_name]}
      label="Report"
      type="select"
      options={@available_reports}
    />

    <.input
      field={@form[:cron_expression]}
      label="Schedule (Cron)"
      placeholder="0 9 * * MON"
    />

    <.input
      field={@form[:recipients]}
      label="Email Recipients"
      placeholder="user@example.com"
    />

    <button type="submit">Create Schedule</button>
  </form>
  ```

- [ ] Execution history
  - Past executions
  - Success/failure status
  - Execution duration
  - Error messages
  - Result previews

- [ ] Failure notifications
  - Email alerts
  - In-app notifications
  - Retry configuration
  - Escalation rules

---

## Section 5.2: User Experience Enhancements

### 5.2.1 Dark Mode Support

**Files**: Multiple CSS and component updates
**Estimated Changes**: ~200 lines across multiple files

#### Purpose
Full dark mode support with theme persistence.

#### Tasks
- [ ] Implement dark mode across all components
  ```css
  /* assets/css/app.css */
  @media (prefers-color-scheme: dark) {
    :root {
      --bg-primary: #1a1a1a;
      --bg-secondary: #2d2d2d;
      --text-primary: #f0f0f0;
      --text-secondary: #b0b0b0;
      /* More variables */
    }
  }

  [data-theme="dark"] {
    /* Force dark mode */
  }
  ```

- [ ] Toggle switch in navigation
  ```heex
  <button
    phx-click="toggle_theme"
    aria-label="Toggle dark mode"
    class="theme-toggle"
  >
    <.icon name={if @theme == :dark, do: "hero-sun", else: "hero-moon"} />
  </button>
  ```

- [ ] Dark mode CSS classes
  - Define CSS variables for colors
  - Create dark theme variants
  - Ensure contrast ratios meet WCAG standards
  - Test with charts and reports

- [ ] Chart theme switching (dark palettes)
  ```elixir
  defp get_chart_theme_for_mode(mode) do
    case mode do
      :dark -> :dark_minimal
      :light -> :default
    end
  end
  ```

- [ ] Local storage persistence
  ```javascript
  // assets/js/theme.js
  export const ThemeManager = {
    get() {
      return localStorage.getItem("theme") || "light";
    },

    set(theme) {
      localStorage.setItem("theme", theme);
      document.documentElement.setAttribute("data-theme", theme);
    },

    toggle() {
      const current = this.get();
      const next = current === "light" ? "dark" : "light";
      this.set(next);
      return next;
    }
  };
  ```

- [ ] System preference detection
  ```javascript
  // Detect system preference on load
  const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;

  if (!localStorage.getItem("theme")) {
    ThemeManager.set(prefersDark ? "dark" : "light");
  }
  ```

---

### 5.2.2 Responsive Design

**Files**: CSS updates and component refinements
**Estimated Changes**: ~300 lines

#### Purpose
Mobile-first responsive design for all screen sizes.

#### Tasks
- [ ] Enhance mobile responsiveness
  ```css
  /* Mobile-first approach */
  .report-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: 1rem;
  }

  @media (min-width: 640px) {
    .report-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }

  @media (min-width: 1024px) {
    .report-grid {
      grid-template-columns: repeat(3, 1fr);
    }
  }
  ```

- [ ] Mobile-optimized layouts
  - Stack elements vertically on small screens
  - Larger touch targets (min 44x44px)
  - Simplified navigation
  - Bottom navigation bar

- [ ] Touch-friendly controls
  - Larger buttons and inputs
  - Adequate spacing
  - Swipe gestures
  - Pull-to-refresh

- [ ] Collapsible sidebars
  ```heex
  <aside class={[
    "sidebar",
    @sidebar_open && "open" || "closed"
  ]}>
    <button
      class="sidebar-toggle"
      phx-click="toggle_sidebar"
    >
      <.icon name="hero-bars-3" />
    </button>
    <!-- Sidebar content -->
  </aside>
  ```

- [ ] Mobile-specific chart sizing
  ```elixir
  defp get_responsive_chart_config(device_type) do
    case device_type do
      :mobile -> %{width: 350, height: 250}
      :tablet -> %{width: 500, height: 350}
      :desktop -> %{width: 800, height: 500}
    end
  end
  ```

- [ ] Bottom navigation on mobile
  ```heex
  <nav class="mobile-nav" data-device="mobile">
    <.link navigate={~p"/reports"} class="nav-item">
      <.icon name="hero-document-text" />
      <span>Reports</span>
    </.link>
    <!-- More nav items -->
  </nav>
  ```

---

### 5.2.3 Keyboard Shortcuts

**File**: `lib/ash_reports_demo_web/components/keyboard_shortcuts.ex`
**Estimated Lines**: ~100

#### Purpose
Keyboard shortcuts for power users with discoverable overlay.

#### Tasks
- [ ] Create `KeyboardShortcuts` component
  ```elixir
  defmodule AshReportsDemoWeb.Components.KeyboardShortcuts do
    use Phoenix.Component

    def shortcuts_modal(assigns)
    def shortcuts_listener(assigns)
  end
  ```

- [ ] Keyboard shortcut overlay
  ```heex
  <div
    class="shortcuts-modal"
    :if={@show_shortcuts}
    phx-click-away="hide_shortcuts"
  >
    <h3>Keyboard Shortcuts</h3>
    <dl class="shortcuts-list">
      <dt><kbd>Cmd</kbd> + <kbd>Enter</kbd></dt>
      <dd>Run report</dd>

      <dt><kbd>Cmd</kbd> + <kbd>E</kbd></dt>
      <dd>Export report</dd>

      <!-- More shortcuts -->
    </dl>
  </div>
  ```

- [ ] Common actions implementation
  ```javascript
  // assets/js/shortcuts.js
  document.addEventListener("keydown", (e) => {
    // Cmd/Ctrl + Enter: Run report
    if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
      e.preventDefault();
      document.querySelector("[data-action='run-report']")?.click();
    }

    // Cmd/Ctrl + E: Export
    if ((e.metaKey || e.ctrlKey) && e.key === "e") {
      e.preventDefault();
      document.querySelector("[data-action='export']")?.click();
    }

    // Cmd/Ctrl + K: Search
    if ((e.metaKey || e.ctrlKey) && e.key === "k") {
      e.preventDefault();
      document.querySelector("[data-action='search']")?.focus();
    }

    // Cmd/Ctrl + /: Show shortcuts
    if ((e.metaKey || e.ctrlKey) && e.key === "/") {
      e.preventDefault();
      window.dispatchEvent(new CustomEvent("show-shortcuts"));
    }
  });
  ```

- [ ] Supported shortcuts:
  - `Cmd+Enter` - Run report
  - `Cmd+E` - Export report
  - `Cmd+K` - Focus search
  - `Cmd+/` - Show shortcuts help
  - `Esc` - Close modals
  - `/` - Focus global search (when not in input)

---

## Section 5.3: Documentation & Help

### 5.3.1 In-App Documentation

**File**: `lib/ash_reports_demo_web/live/docs_live/index.ex`
**Estimated Lines**: ~350

#### Purpose
Comprehensive in-app documentation with interactive examples.

#### Tasks
- [ ] Create `DocsLive.Index` LiveView
  ```elixir
  defmodule AshReportsDemoWeb.DocsLive.Index do
    use AshReportsDemoWeb, :live_view

    def mount(%{"section" => section}, _session, socket) do
      {:ok, load_documentation_section(socket, section)}
    end
  end
  ```

- [ ] Report DSL reference
  ```heex
  <section class="docs-section">
    <h2>Report DSL Reference</h2>

    <article>
      <h3>Report Definition</h3>
      <pre><code class="language-elixir">
  report :customer_summary do
    description "Customer analytics summary"
    driving_resource Customer

    parameter :region, :string
    parameter :tier, :string

    # More DSL examples
  end
      </code></pre>
      <p>Detailed explanation...</p>
    </article>
  </section>
  ```

- [ ] Chart API documentation
  - Chart types and their data formats
  - Configuration options
  - Theme customization
  - Performance tips

- [ ] Pipeline architecture explanation
  - Three-stage pipeline diagram
  - Data flow visualization
  - Error handling guide
  - Best practices

- [ ] Code examples
  - Copy-paste ready code
  - Syntax highlighting
  - Live examples
  - Runnable demos

- [ ] Interactive tutorials
  ```heex
  <div class="tutorial">
    <div class="tutorial-steps">
      <div
        :for={{step, index} <- Enum.with_index(@tutorial.steps)}
        class={step_class(step, @current_step)}
      >
        <h4>Step <%= index + 1 %>: <%= step.title %></h4>
        <p><%= step.description %></p>
        <button
          :if={step.action}
          phx-click={step.action}
        >
          <%= step.action_label %>
        </button>
      </div>
    </div>
  </div>
  ```

---

### 5.3.2 Report Tooltips

**File**: Enhancement to existing components
**Estimated Changes**: ~80 lines

#### Purpose
Contextual help via tooltips throughout the UI.

#### Tasks
- [ ] Create tooltip system for reports
  ```elixir
  defmodule AshReportsDemoWeb.Components.Tooltip do
    use Phoenix.Component

    attr :content, :string, required: true
    attr :position, :string, default: "top"
    slot :inner_block, required: true

    def tooltip(assigns)
  end
  ```

- [ ] Parameter tooltips with descriptions
  ```heex
  <.tooltip content={@parameter.description}>
    <label for={@parameter.name}>
      <%= humanize(@parameter.name) %>
    </label>
  </.tooltip>
  ```

- [ ] Format explanations
  - When to use each format
  - Format capabilities
  - Performance characteristics

- [ ] Variable descriptions
  - Variable type explanation
  - Reset scope meaning
  - Common use cases

- [ ] Group explanations
  - Grouping hierarchy
  - Level meanings
  - Impact on output

- [ ] Band descriptions
  - Band type purposes
  - When to use each band
  - Element placement rules

---

## Deliverables

### Code Deliverables
- [ ] `ReportLive.Library` - Report browsing interface
- [ ] `ScheduleLive.Index` - Report scheduling (optional)
- [ ] Dark mode implementation - Theme system
- [ ] Responsive design updates - Mobile-first CSS
- [ ] `KeyboardShortcuts` component - Shortcut system
- [ ] `DocsLive.Index` - In-app documentation
- [ ] `Tooltip` component - Contextual help

### Documentation
- [ ] User guide for new features
- [ ] Dark mode implementation guide
- [ ] Keyboard shortcuts reference
- [ ] Responsive design guidelines

### Success Metrics
- [ ] Works on mobile devices (tested iOS/Android)
- [ ] Dark mode toggle functional
- [ ] Keyboard shortcuts work reliably
- [ ] Documentation comprehensive and searchable
- [ ] Tooltips provide helpful context

---

## Testing Requirements

### UI Tests
- [ ] Dark mode rendering tests
- [ ] Responsive layout tests (multiple viewports)
- [ ] Keyboard shortcut tests
- [ ] Tooltip display tests

### Integration Tests
- [ ] Report library search and filter
- [ ] Favorites functionality
- [ ] Scheduling (if implemented)
- [ ] Documentation navigation

### Accessibility Tests
- [ ] Screen reader compatibility
- [ ] Keyboard navigation
- [ ] Color contrast ratios
- [ ] ARIA labels

---

## Dependencies

### External Dependencies
- Oban (optional, for scheduling)
- Swoosh (optional, for email)

### Internal Dependencies
- All previous phases

---

## Next Phase

After Phase 5 completion, proceed to:
- **Phase 6**: Testing & Documentation
  - Comprehensive test suite
  - Final documentation
  - Performance validation
