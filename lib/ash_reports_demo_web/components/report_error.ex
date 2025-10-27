defmodule AshReportsDemoWeb.Components.ReportError do
  @moduledoc """
  Reusable LiveView component for displaying pipeline errors with stage context
  and suggested actions.

  This component provides:
  - Visual pipeline diagram showing failure point
  - Stage-based error messages
  - Suggested actions for recovery
  - Retry mechanisms
  - Error details expansion/collapse

  ## Usage

      <.report_error
        error={@error_data}
        retry_event="retry_report"
      />

  ## With optional parameters

      <.report_error
        error={@error_data}
        retry_event="retry_report"
        show_technical_details={true}
        max_retries={3}
      />

  """

  use Phoenix.Component

  attr :error, :map,
    required: true,
    doc: "Error map containing stage, reason, user_message, and suggested_action"

  attr :retry_event, :string,
    default: nil,
    doc: "Event name to send when retry button is clicked"

  attr :show_technical_details, :boolean,
    default: false,
    doc: "Whether to show technical details by default"

  attr :max_retries, :integer,
    default: 3,
    doc: "Maximum number of retry attempts"

  attr :retry_count, :integer,
    default: 0,
    doc: "Current retry attempt count"

  @doc """
  Render an error display component for pipeline failures.
  """
  def report_error(assigns) do
    ~H"""
    <div class="report-error-container bg-red-50 border border-red-200 rounded-lg p-6 my-4">
      <!-- Error Header -->
      <div class="error-header flex items-start justify-between mb-4">
        <div class="flex items-center">
          <svg class="w-6 h-6 text-red-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <div>
            <h3 class="text-lg font-semibold text-red-900">Report Generation Failed</h3>
            <span class="text-sm text-red-700">
              Error in <span class="font-mono bg-red-100 px-2 py-1 rounded"><%= format_stage(@error.stage) %></span> stage
            </span>
          </div>
        </div>
      </div>

      <!-- Pipeline Visualization -->
      <div class="pipeline-visualization mb-4">
        <.pipeline_diagram stage={@error.stage} />
      </div>

      <!-- Error Message -->
      <div class="error-message bg-white border border-red-200 rounded p-4 mb-4">
        <p class="text-red-900 mb-2">
          <%= @error.user_message %>
        </p>
        <p class="text-sm text-gray-700">
          <span class="font-semibold">Suggested action:</span>
          <%= @error.suggested_action %>
        </p>
      </div>

      <!-- Technical Details (Collapsible) -->
      <details class="technical-details mb-4" open={@show_technical_details}>
        <summary class="cursor-pointer text-sm font-medium text-gray-700 hover:text-gray-900 select-none">
          Technical Details
        </summary>
        <div class="mt-2 bg-gray-50 border border-gray-200 rounded p-3">
          <pre class="text-xs text-gray-800 whitespace-pre-wrap font-mono"><%= Map.get(@error, :technical_details) || inspect(@error.reason) %></pre>
        </div>
      </details>

      <!-- Action Buttons -->
      <div class="error-actions flex gap-3">
        <%= if @retry_event && @retry_count < @max_retries do %>
          <button
            type="button"
            phx-click={@retry_event}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            Retry Report
            <%= if @retry_count > 0 do %>
              <span class="ml-1 text-xs">(Attempt <%= @retry_count + 1 %>/<%= @max_retries %>)</span>
            <% end %>
          </button>
        <% end %>

        <%= if @retry_count >= @max_retries do %>
          <div class="text-sm text-red-600 flex items-center">
            <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
            </svg>
            Maximum retry attempts reached
          </div>
        <% end %>

        <a
          href="#"
          phx-click="edit_parameters"
          class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
          Edit Parameters
        </a>
      </div>
    </div>
    """
  end

  @doc """
  Visual pipeline diagram showing which stage failed.
  """
  attr :stage, :atom, required: true

  def pipeline_diagram(assigns) do
    ~H"""
    <div class="flex items-center justify-between space-x-2 text-sm">
      <%= for {stage_name, stage_atom} <- pipeline_stages() do %>
        <div class={"flex-1 flex items-center #{stage_status_class(stage_atom, @stage)}"}>
          <div class="flex items-center justify-center w-full">
            <div class={"rounded-full p-2 #{stage_icon_class(stage_atom, @stage)}"}>
              <%= stage_icon(stage_atom, @stage) %>
            </div>
            <div class="ml-2 text-xs font-medium">
              <%= stage_name %>
            </div>
          </div>
        </div>

        <%= if stage_atom != :rendering do %>
          <div class={"flex-shrink-0 #{arrow_class(stage_atom, @stage)}"}>
            →
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # Private helper functions

  defp pipeline_stages do
    [
      {"Data Loading", :data_loading},
      {"Context Building", :context_building},
      {"Rendering", :rendering}
    ]
  end

  defp stage_status_class(stage_atom, failed_stage) do
    cond do
      stage_atom == failed_stage -> "text-red-700"
      stage_comes_before?(stage_atom, failed_stage) -> "text-green-700"
      true -> "text-gray-400"
    end
  end

  defp stage_icon_class(stage_atom, failed_stage) do
    cond do
      stage_atom == failed_stage -> "bg-red-100 text-red-600"
      stage_comes_before?(stage_atom, failed_stage) -> "bg-green-100 text-green-600"
      true -> "bg-gray-100 text-gray-400"
    end
  end

  defp arrow_class(stage_atom, failed_stage) do
    if stage_comes_before?(stage_atom, failed_stage) do
      "text-green-600"
    else
      "text-gray-300"
    end
  end

  defp stage_icon(stage_atom, failed_stage) do
    cond do
      stage_atom == failed_stage ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
        </svg>
        """)

      stage_comes_before?(stage_atom, failed_stage) ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
        </svg>
        """)

      true ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v3.586L7.707 9.293a1 1 0 00-1.414 1.414l3 3a1 1 0 001.414 0l3-3a1 1 0 00-1.414-1.414L11 10.586V7z" clip-rule="evenodd" />
        </svg>
        """)
    end
  end

  defp stage_comes_before?(stage, failed_stage) do
    stages_order = [:data_loading, :context_building, :rendering]
    stage_index = Enum.find_index(stages_order, &(&1 == stage))
    failed_index = Enum.find_index(stages_order, &(&1 == failed_stage))

    stage_index != nil && failed_index != nil && stage_index < failed_index
  end

  defp format_stage(stage) when is_atom(stage) do
    stage
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_stage(stage), do: inspect(stage)
end
