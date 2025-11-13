defmodule AshReportsDemoWeb.DashboardLive.Index do
  use AshReportsDemoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:selected_view, "session_analytics")
     |> assign(:session_stats, load_session_stats())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("change_view", %{"view" => view}, socket) do
    # Sync session data when changing views
    AshReportsDemo.SessionDataSync.sync_session_data()

    {:noreply,
     socket
     |> assign(:selected_view, view)
     |> assign(:session_stats, load_session_stats())}
  end

  @impl true
  def handle_event("refresh_stats", _params, socket) do
    {:noreply,
     socket
     |> assign(:session_stats, load_session_stats())
     |> put_flash(:info, "Statistics refreshed!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-xl">
      <.header class="text-center">
        Dashboard
        <:subtitle>
          Session tracking and application usage analytics
        </:subtitle>
      </.header>
    </div>

    <div class="mt-8">
      <!-- Session Analytics Section -->
      <div class="bg-gradient-to-br from-[#2F5597] to-[#4472C4] rounded-lg shadow-lg p-6">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h2 class="text-lg font-semibold text-white">Usage Analytics</h2>
            <p class="text-sm text-[#B4C6E7] mt-1">Session tracking and application usage statistics</p>
          </div>
          <div class="flex items-center gap-3">
            <form phx-change="change_view" class="relative">
              <select
                name="view"
                class="appearance-none bg-white text-gray-700 border border-gray-200 rounded-lg pl-4 pr-10 py-2 focus:outline-none focus:ring-2 focus:ring-white/50 font-medium"
              >
                <option value="session_analytics" selected={@selected_view == "session_analytics"}>
                  Session Analytics
                </option>
                <option value="session_details" selected={@selected_view == "session_details"}>
                  Session Details
                </option>
                <option value="engagement_metrics" selected={@selected_view == "engagement_metrics"}>
                  Engagement Metrics
                </option>
                <option value="telemetry_metrics" selected={@selected_view == "telemetry_metrics"}>
                  Performance Metrics
                </option>
                <option value="performance_charts" selected={@selected_view == "performance_charts"}>
                  Performance Charts
                </option>
              </select>
              <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
                <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
              </div>
            </form>
            <button
              type="button"
              phx-click="refresh_stats"
              class="bg-white/20 hover:bg-white/30 text-white px-4 py-2 rounded-lg font-medium transition-colors"
            >
              Refresh
            </button>
            <div class="bg-white/20 rounded-full p-3">
              <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </div>
          </div>
        </div>
        
        <%= case @selected_view do %>
          <% "session_analytics" -> %>
            <.session_analytics_view session_stats={@session_stats} />
          <% "session_details" -> %>
            <.session_details_view session_stats={@session_stats} />
          <% "engagement_metrics" -> %>
            <.engagement_metrics_view session_stats={@session_stats} />
          <% "telemetry_metrics" -> %>
            <.telemetry_metrics_view />
          <% "performance_charts" -> %>
            <.performance_charts_view />
        <% end %>
      </div>
    </div>
    """
  end

  defp session_analytics_view(assigns) do
    ~H"""
    <div>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-[#B4C6E7] text-sm font-medium">Total Sessions</p>
              <p class="text-3xl font-bold text-white mt-1"><%= @session_stats.total_sessions %></p>
            </div>
            <div class="bg-white/20 rounded-full p-3">
              <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
            </div>
          </div>
        </div>

        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-[#B4C6E7] text-sm font-medium">Active Sessions</p>
              <p class="text-3xl font-bold text-white mt-1"><%= @session_stats.active_sessions %></p>
            </div>
            <div class="bg-white/20 rounded-full p-3">
              <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
          </div>
        </div>
        
        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-[#B4C6E7] text-sm font-medium">Total Page Views</p>
              <p class="text-3xl font-bold text-white mt-1"><%= @session_stats.total_page_views %></p>
            </div>
            <div class="bg-white/20 rounded-full p-3">
              <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
            </div>
          </div>
        </div>

        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-[#B4C6E7] text-sm font-medium">Avg. Views/Session</p>
              <p class="text-3xl font-bold text-white mt-1"><%= @session_stats.average_page_views %></p>
            </div>
            <div class="bg-white/20 rounded-full p-3">
              <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 8v8m-4-5v5m-4-2v2m-2 4h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
            </div>
          </div>
        </div>
      </div>
      
      <%= if @session_stats.oldest_session || @session_stats.newest_session do %>
        <div class="pt-6 border-t border-white/20">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
            <%= if @session_stats.oldest_session do %>
              <div class="text-[#B4C6E7]">
                <span class="font-medium">First session:</span>
                <%= format_datetime(@session_stats.oldest_session) %>
              </div>
            <% end %>
            <%= if @session_stats.newest_session do %>
              <div class="text-[#B4C6E7]">
                <span class="font-medium">Latest session:</span>
                <%= format_datetime(@session_stats.newest_session) %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
      
      <!-- Session Activity Chart -->
      <div class="mt-6 pt-6 border-t border-white/20">
        <h3 class="text-lg font-semibold text-white mb-4">Session Activity Timeline</h3>
        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20">
          <.live_component 
            module={AshReportsDemoWeb.Components.InlineChart}
            id="session-activity-chart"
            chart_name={:session_activity_timeline}
          />
        </div>
      </div>
    </div>
    """
  end

  defp session_details_view(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
          <h3 class="text-lg font-semibold text-white mb-4">Session Duration</h3>
          <div class="space-y-3">
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">Active session time:</span>
              <span class="text-white font-medium"><%= format_session_duration(@session_stats) %></span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">Session timeout:</span>
              <span class="text-white font-medium">24 hours</span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">Cleanup frequency:</span>
              <span class="text-white font-medium">Every hour</span>
            </div>
          </div>
        </div>

        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
          <h3 class="text-lg font-semibold text-white mb-4">Session Storage</h3>
          <div class="space-y-3">
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">Storage type:</span>
              <span class="text-white font-medium">ETS Table</span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">Persistence:</span>
              <span class="text-white font-medium">In-memory</span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">Auto cleanup:</span>
              <span class="text-white font-medium">Enabled</span>
            </div>
          </div>
        </div>
      </div>

      <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
        <h3 class="text-lg font-semibold text-white mb-4">Session Tracking Details</h3>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
          <div>
            <p class="text-[#B4C6E7] mb-2">Data Captured:</p>
            <ul class="text-white space-y-1">
              <li>• Session ID</li>
              <li>• First seen timestamp</li>
              <li>• Last seen timestamp</li>
              <li>• Page view count</li>
              <li>• User agent string</li>
            </ul>
          </div>
          <div>
            <p class="text-[#B4C6E7] mb-2">Privacy Features:</p>
            <ul class="text-white space-y-1">
              <li>• No personal data stored</li>
              <li>• Anonymous session IDs</li>
              <li>• Automatic cleanup</li>
              <li>• Temporary storage only</li>
            </ul>
          </div>
          <div>
            <p class="text-[#B4C6E7] mb-2">Technical Details:</p>
            <ul class="text-white space-y-1">
              <li>• GenServer process</li>
              <li>• Phoenix session integration</li>
              <li>• Real-time tracking</li>
              <li>• Error handling</li>
            </ul>
          </div>
        </div>
      </div>
      
      <!-- Page Views Distribution Chart -->
      <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
        <h3 class="text-lg font-semibold text-white mb-4">Page Views Distribution</h3>
        <.live_component 
          module={AshReportsDemoWeb.Components.InlineChart}
          id="page-views-chart"
          chart_name={:page_views_distribution}
        />
      </div>
    </div>
    """
  end

  defp engagement_metrics_view(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20 text-center">
          <div class="bg-white/20 rounded-full p-4 w-fit mx-auto mb-4">
            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-white mb-2">Growth Rate</h3>
          <p class="text-3xl font-bold text-white"><%= calculate_growth_rate(@session_stats) %>%</p>
          <p class="text-[#B4C6E7] text-sm mt-1">Session growth</p>
        </div>

        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20 text-center">
          <div class="bg-white/20 rounded-full p-4 w-fit mx-auto mb-4">
            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-white mb-2">Avg. Session Length</h3>
          <p class="text-3xl font-bold text-white"><%= format_avg_session_length(@session_stats) %></p>
          <p class="text-[#B4C6E7] text-sm mt-1">Minutes per session</p>
        </div>

        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20 text-center">
          <div class="bg-white/20 rounded-full p-4 w-fit mx-auto mb-4">
            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-white mb-2">Bounce Rate</h3>
          <p class="text-3xl font-bold text-white"><%= calculate_bounce_rate(@session_stats) %>%</p>
          <p class="text-[#B4C6E7] text-sm mt-1">Single page visits</p>
        </div>
      </div>

      <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
        <h3 class="text-lg font-semibold text-white mb-4">Usage Patterns</h3>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div class="text-center">
            <p class="text-2xl font-bold text-white"><%= @session_stats.total_sessions %></p>
            <p class="text-[#B4C6E7] text-sm">Total Visitors</p>
          </div>
          <div class="text-center">
            <p class="text-2xl font-bold text-white"><%= @session_stats.active_sessions %></p>
            <p class="text-[#B4C6E7] text-sm">Active Now</p>
          </div>
          <div class="text-center">
            <p class="text-2xl font-bold text-white"><%= @session_stats.total_page_views %></p>
            <p class="text-[#B4C6E7] text-sm">Page Views</p>
          </div>
          <div class="text-center">
            <p class="text-2xl font-bold text-white"><%= @session_stats.average_page_views %></p>
            <p class="text-[#B4C6E7] text-sm">Pages/Session</p>
          </div>
        </div>
      </div>
      
      <!-- Bounce Rate Analysis Chart -->
      <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
        <h3 class="text-lg font-semibold text-white mb-4">Session Engagement Analysis</h3>
        <.live_component 
          module={AshReportsDemoWeb.Components.InlineChart}
          id="bounce-rate-chart"
          chart_name={:bounce_rate_analysis}
        />
      </div>
    </div>
    """
  end

  defp load_session_stats do
    try do
      AshReportsDemo.SessionTracker.get_session_stats()
    rescue
      _ ->
        %{
          total_sessions: 0,
          active_sessions: 0,
          total_page_views: 0,
          average_page_views: 0,
          oldest_session: nil,
          newest_session: nil
        }
    end
  end

  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%b %d, %Y at %I:%M %p UTC")
  end

  defp format_datetime(_), do: "N/A"

  defp format_session_duration(session_stats) do
    case {session_stats.oldest_session, session_stats.newest_session} do
      {%DateTime{} = oldest, %DateTime{} = newest} ->
        diff = DateTime.diff(newest, oldest, :minute)
        if diff > 0, do: "#{diff} minutes", else: "< 1 minute"

      _ ->
        "N/A"
    end
  end

  defp calculate_growth_rate(_session_stats) do
    # For demo purposes, showing a simple growth calculation
    # In a real app, this would compare with previous periods
    "+12.5"
  end

  defp format_avg_session_length(session_stats) do
    # Simple calculation based on total time / sessions
    case {session_stats.oldest_session, session_stats.newest_session,
          session_stats.total_sessions} do
      {%DateTime{} = oldest, %DateTime{} = newest, total} when total > 0 ->
        total_minutes = DateTime.diff(newest, oldest, :minute)
        avg = if total_minutes > 0, do: div(total_minutes, total), else: 0
        "#{avg}"

      _ ->
        "0"
    end
  end

  defp calculate_bounce_rate(session_stats) do
    # Calculate percentage of sessions with only 1 page view
    if session_stats.total_sessions > 0 do
      single_page_sessions =
        session_stats.total_sessions -
          (session_stats.total_page_views - session_stats.total_sessions)

      bounce_rate =
        if single_page_sessions > 0,
          do: round(single_page_sessions / session_stats.total_sessions * 100),
          else: 0

      max(0, bounce_rate)
    else
      0
    end
  end

  defp telemetry_metrics_view(assigns) do
    telemetry_metrics =
      try do
        AshReportsDemoWeb.TelemetryCollector.get_metrics()
      rescue
        _ -> %{}
      end

    performance_stats =
      try do
        AshReportsDemoWeb.TelemetryCollector.get_performance_stats()
      rescue
        _ -> %{requests_per_second: 0, error_rate: 0, cache_hit_rate: 0, performance_score: 0}
      end

    assigns = assign(assigns, :telemetry_metrics, telemetry_metrics)
    assigns = assign(assigns, :performance_stats, performance_stats)

    ~H"""
    <div class="space-y-6">
      <!-- Performance Overview -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20 text-center">
          <div class="bg-white/20 rounded-full p-4 w-fit mx-auto mb-4">
            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-white mb-2">Performance Score</h3>
          <p class="text-3xl font-bold text-white"><%= @performance_stats.performance_score %></p>
          <p class="text-[#B4C6E7] text-sm mt-1">Overall health</p>
        </div>

        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20 text-center">
          <div class="bg-white/20 rounded-full p-4 w-fit mx-auto mb-4">
            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-white mb-2">Avg Response</h3>
          <p class="text-3xl font-bold text-white"><%= Float.round(@telemetry_metrics[:avg_request_time] || 0, 1) %>ms</p>
          <p class="text-[#B4C6E7] text-sm mt-1">Request time</p>
        </div>

        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20 text-center">
          <div class="bg-white/20 rounded-full p-4 w-fit mx-auto mb-4">
            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" />
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-white mb-2">Cache Hit Rate</h3>
          <p class="text-3xl font-bold text-white"><%= @performance_stats.cache_hit_rate %>%</p>
          <p class="text-[#B4C6E7] text-sm mt-1">Chart caching</p>
        </div>

        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20 text-center">
          <div class="bg-white/20 rounded-full p-4 w-fit mx-auto mb-4">
            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-white mb-2">Error Rate</h3>
          <p class="text-3xl font-bold text-white"><%= @performance_stats.error_rate %>%</p>
          <p class="text-[#B4C6E7] text-sm mt-1">Request errors</p>
        </div>
      </div>

      <!-- Detailed Metrics -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
          <h3 class="text-lg font-semibold text-white mb-4">Request Metrics</h3>
          <div class="space-y-3">
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">Total Requests:</span>
              <span class="text-white font-medium"><%= @telemetry_metrics[:total_requests] || 0 %></span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">Socket Connections:</span>
              <span class="text-white font-medium"><%= @telemetry_metrics[:socket_connections] || 0 %></span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">LiveView Mounts:</span>
              <span class="text-white font-medium"><%= @telemetry_metrics[:lv_mounts] || 0 %></span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">LiveView Events:</span>
              <span class="text-white font-medium"><%= @telemetry_metrics[:lv_events] || 0 %></span>
            </div>
          </div>
        </div>

        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
          <h3 class="text-lg font-semibold text-white mb-4">Chart Performance</h3>
          <div class="space-y-3">
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">Charts Generated:</span>
              <span class="text-white font-medium"><%= @telemetry_metrics[:charts_generated] || 0 %></span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">Cache Hits:</span>
              <span class="text-white font-medium"><%= @telemetry_metrics[:chart_cache_hits] || 0 %></span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">Cache Misses:</span>
              <span class="text-white font-medium"><%= @telemetry_metrics[:chart_cache_misses] || 0 %></span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-[#B4C6E7] text-sm">Avg Generation Time:</span>
              <span class="text-white font-medium"><%= Float.round(@telemetry_metrics[:avg_chart_generation_time] || 0, 1) %>ms</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp performance_charts_view(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="text-center mb-6">
        <h3 class="text-xl font-bold text-white mb-2">Performance Analytics</h3>
        <p class="text-[#B4C6E7]">Real-time visualization of system performance metrics</p>
      </div>

      <!-- Chart Data Query Performance Over Time -->
      <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
        <h4 class="text-lg font-semibold text-white mb-4">Chart Data Query Performance Over Time</h4>
        <div class="bg-white rounded-lg p-4">
          <.live_component 
            module={AshReportsDemoWeb.Components.InlineChart}
            id="chart-query-performance-timeline"
            chart_name={:chart_query_performance_timeline}
          />
        </div>
        <p class="text-[#B4C6E7] text-sm mt-3 text-center">Shows data loading and transformation performance trends</p>
      </div>

      <!-- Chart Generation Performance Over Time -->
      <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
        <h4 class="text-lg font-semibold text-white mb-4">Chart Generation Performance Over Time</h4>
        <div class="bg-white rounded-lg p-4">
          <.live_component 
            module={AshReportsDemoWeb.Components.InlineChart}
            id="chart-generation-performance-timeline"
            chart_name={:chart_generation_performance_timeline}
          />
        </div>
        <p class="text-[#B4C6E7] text-sm mt-3 text-center">Shows SVG chart rendering performance trends</p>
      </div>

      <!-- Performance Comparison Charts Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Average Performance by Operation Type -->
        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
          <h4 class="text-lg font-semibold text-white mb-4">Average Performance by Operation</h4>
          <div class="bg-white rounded-lg p-4">
            <.live_component 
              module={AshReportsDemoWeb.Components.InlineChart}
              id="request-performance-distribution"
              chart_name={:request_performance_distribution}
            />
          </div>
          <p class="text-[#B4C6E7] text-sm mt-3 text-center">Comparison of different operation types</p>
        </div>

        <!-- Performance Trends Area Chart -->
        <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
          <h4 class="text-lg font-semibold text-white mb-4">Performance Trends</h4>
          <div class="bg-white rounded-lg p-4">
            <.live_component 
              module={AshReportsDemoWeb.Components.InlineChart}
              id="performance-trends-comparison"
              chart_name={:performance_trends_comparison}
            />
          </div>
          <p class="text-[#B4C6E7] text-sm mt-3 text-center">5-minute rolling averages</p>
        </div>
      </div>

      <!-- Performance Insights -->
      <div class="bg-white/10 backdrop-blur-sm rounded-lg p-6 border border-white/20">
        <h4 class="text-lg font-semibold text-white mb-4">Performance Insights</h4>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
          <div>
            <p class="text-[#B4C6E7] mb-2">Data Query Phase:</p>
            <ul class="text-white space-y-1">
              <li>• Data loading from resources</li>
              <li>• Transform execution</li>
              <li>• Data type conversions</li>
              <li>• Filtering and aggregations</li>
            </ul>
          </div>
          <div>
            <p class="text-[#B4C6E7] mb-2">Generation Phase:</p>
            <ul class="text-white space-y-1">
              <li>• SVG chart rendering</li>
              <li>• Layout calculations</li>
              <li>• Styling applications</li>
              <li>• Optimization passes</li>
            </ul>
          </div>
          <div>
            <p class="text-[#B4C6E7] mb-2">Optimization Tips:</p>
            <ul class="text-white space-y-1">
              <li>• Cache frequently used data</li>
              <li>• Limit data point counts</li>
              <li>• Use efficient transforms</li>
              <li>• Monitor memory usage</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
