defmodule AshReportsDemoWeb.Components.ChartTemplateViewer do
  @moduledoc """
  Component for displaying actual chart definitions from the Domain DSL.

  Extracts and displays the real AshReports Chart DSL code used to define
  charts in the domain.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :chart_name, :atom,
    required: true,
    doc: "The name of the chart to display definition for"

  @doc """
  Render the actual chart definition from the Domain DSL.
  """
  def chart_template_viewer(assigns) do
    template = extract_chart_from_domain(assigns.chart_name)
    assigns = assign(assigns, :template, template)

    ~H"""
    <div>
      <div class="flex items-center justify-between mb-4">
        <div>
          <h3 class="text-lg font-medium text-gray-900">
            Chart Definition (AshReports DSL)
          </h3>
          <p class="mt-1 text-sm text-gray-600">
            The actual chart definition from the Domain using AshReports Chart DSL
          </p>
        </div>
        <button
          type="button"
          phx-click={JS.dispatch("phx:copy", to: "#chart-template-code")}
          class="inline-flex items-center px-3 py-1 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
        >
          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
          </svg>
          Copy
        </button>
      </div>

      <div class="relative" style="max-height: 600px; overflow-y: auto;">
        <pre
          id="chart-template-code"
          phx-hook="HighlightCode"
          class="bg-gray-900 text-gray-100 rounded-lg p-4 overflow-x-auto text-sm font-mono leading-relaxed"
        ><code class="language-elixir" phx-no-format><%= @template %></code></pre>
      </div>
      
      <div class="mt-4 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div class="flex">
          <svg class="w-5 h-5 text-blue-600 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
          </svg>
          <div class="text-sm text-blue-800">
            <p class="font-medium">Chart DSL Architecture:</p>
            <p class="mt-1">Charts are defined as standalone entities at the domain level and can be referenced in report bands. The data_source uses helper functions to fetch and format data from Ash resources.</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp extract_chart_from_domain(chart_name) do
    source_path = "lib/ash_reports_demo/domain.ex"

    if File.exists?(source_path) do
      source_path
      |> File.read!()
      |> extract_chart_definition(chart_name)
    else
      "# Domain file not found"
    end
  rescue
    _ -> "# Error reading chart definition"
  end

  defp extract_chart_definition(source_content, chart_name) do
    chart_name_str = Atom.to_string(chart_name)
    chart_type = get_chart_type(chart_name_str)

    # Match the specific chart definition with proper boundaries
    pattern =
      ~r/\s*#{chart_type}\s+:#{chart_name_str}\s+do\n(.*?)\n\s*end\n\s*(?:#|$|\w+_chart|report)/s

    case Regex.run(pattern, source_content) do
      [_full_match, inner_content] ->
        lines = String.split(inner_content, "\n")

        min_indent =
          lines
          |> Enum.reject(&(String.trim(&1) == ""))
          |> Enum.map(&count_leading_spaces/1)
          |> Enum.min(fn -> 0 end)

        formatted_content =
          lines
          |> Enum.map_join("\n", &normalize_line_indent(&1, min_indent))
          |> String.trim()

        code = """
        #{chart_type} :#{chart_name_str} do
          #{formatted_content}
        end
        """

        try do
          Code.format_string!(code) |> IO.iodata_to_binary()
        rescue
          _ -> code
        end

      nil ->
        "# Chart definition not found for :#{chart_name_str} in domain"
    end
  end

  defp get_chart_type(chart_name) do
    cond do
      String.contains?(chart_name, "distribution") ->
        "pie_chart"

      String.contains?(chart_name, "revenue") and String.contains?(chart_name, "monthly") ->
        "line_chart"

      String.contains?(chart_name, "category") ->
        "bar_chart"

      String.contains?(chart_name, "products") ->
        "bar_chart"

      String.contains?(chart_name, "inventory") ->
        "area_chart"

      String.contains?(chart_name, "analysis") ->
        "scatter_chart"

      String.contains?(chart_name, "timeline") ->
        "gantt_chart"

      String.contains?(chart_name, "trend") ->
        "sparkline"

      true ->
        "chart"
    end
  end

  defp normalize_line_indent(line, min_indent) do
    if String.trim(line) == "" do
      ""
    else
      String.slice(line, min(min_indent, String.length(line))..-1//1)
    end
  end

  defp count_leading_spaces(line) do
    line
    |> String.graphemes()
    |> Enum.take_while(&(&1 == " "))
    |> length()
  end
end
