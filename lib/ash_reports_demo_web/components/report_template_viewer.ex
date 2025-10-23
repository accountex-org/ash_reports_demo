defmodule AshReportsDemoWeb.Components.ReportTemplateViewer do
  @moduledoc """
  Component for displaying the Spark DSL report template definition.

  This component reads the report definition from the Domain module source
  and displays it in a formatted, syntax-highlighted code block.
  """

  use Phoenix.Component
  
  alias Phoenix.LiveView.JS

  attr :report_name, :atom, required: true,
    doc: "The name of the report to display"

  attr :domain, :atom, default: AshReportsDemo.Domain,
    doc: "The domain module containing the report"

  @doc """
  Render the Spark DSL template for a report.
  """
  def report_template_viewer(assigns) do
    template = extract_report_template(assigns.domain, assigns.report_name)
    assigns = assign(assigns, :template, template)

    ~H"""
    <%= if @template do %>
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">
          Spark DSL Definition
        </h3>
        <button
          type="button"
          phx-click={JS.dispatch("phx:copy", to: "#report-template-code")}
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
          id="report-template-code"
          phx-hook="CopyToClipboard"
          class="bg-gray-900 text-gray-100 rounded-lg p-4 overflow-x-auto text-sm font-mono leading-relaxed"
        ><code phx-no-format><%= @template %></code></pre>
      </div>
    <% else %>
      <div class="text-center py-12 text-gray-500">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
        <p class="mt-2">Report template not found</p>
      </div>
    <% end %>
    """
  end

  defp extract_report_template(domain, report_name) do
    case find_domain_source(domain) do
      {:ok, source_path} ->
        source_path
        |> File.read!()
        |> extract_report_block(report_name)

      {:error, _} ->
        nil
    end
  rescue
    _ -> nil
  end

  defp find_domain_source(module) do
    module_parts =
      module
      |> Module.split()
      |> Enum.map(&Macro.underscore/1)
    
    filename = List.last(module_parts) <> ".ex"
    
    dir_parts = Enum.slice(module_parts, 0..-2//1)
    
    source_path = Path.join(["lib" | dir_parts] ++ [filename])
    
    if File.exists?(source_path) do
      {:ok, source_path}
    else
      {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  defp extract_report_block(source_content, report_name) do
    report_name_str = Atom.to_string(report_name)

    case Regex.run(
           ~r/report :#{report_name_str} do(.*?)end(?=\s*(?:report |end\s*authorization|end\s*$))/s,
           source_content
         ) do
      [full_match, inner_content] ->
        lines = String.split(inner_content, "\n")

        min_indent =
          lines
          |> Enum.reject(&(String.trim(&1) == ""))
          |> Enum.map(&count_leading_spaces/1)
          |> Enum.min(fn -> 0 end)

        normalized_lines =
          Enum.map(lines, fn line ->
            if String.trim(line) == "" do
              ""
            else
              String.slice(line, min(min_indent, String.length(line))..-1//1)
            end
          end)

        inner = Enum.join(normalized_lines, "\n") |> String.trim()

        """
        report :#{report_name_str} do
        #{inner}
        end
        """

      nil ->
        "# Report template not found for :#{report_name_str}"
    end
  end

  defp count_leading_spaces(line) do
    line
    |> String.graphemes()
    |> Enum.take_while(&(&1 == " "))
    |> length()
  end
end
