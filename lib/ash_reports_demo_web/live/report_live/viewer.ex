defmodule AshReportsDemoWeb.ReportLive.Viewer do
  @moduledoc """
  Universal report viewer that works with all report types and formats through the pipeline.

  This LiveView provides:
  - Dynamic parameter forms based on report definitions
  - Format selection (HTML, PDF, JSON, HEEX)
  - Real-time report execution with loading states
  - Error handling with retry mechanisms
  - Result display with format-specific rendering
  """

  use AshReportsDemoWeb, :live_view

  alias AshReportsDemoWeb.Reports.{PipelineClient, ResultHandler}
  alias AshReportsDemoWeb.Components.{ReportError, ParameterForm}

  @impl true
  def mount(%{"name" => report_name_str}, _session, socket) do
    report_name = String.to_existing_atom(report_name_str)

    case PipelineClient.get_report_info(AshReportsDemo.Domain, report_name) do
      {:ok, report_info} ->
        {:ok, initialize_viewer(socket, report_name, report_info)}

      {:error, :report_not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Report not found: #{report_name}")
         |> redirect(to: ~p"/reports")}
    end
  rescue
    ArgumentError ->
      {:ok,
       socket
       |> put_flash(:error, "Invalid report name: #{report_name_str}")
       |> redirect(to: ~p"/reports")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    format = parse_format(params["format"])
    parameters = parse_parameters(params)

    socket =
      socket
      |> assign(:format, format)
      |> assign(:parameters, parameters)
      |> maybe_auto_run(params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("format_changed", %{"format" => format_str}, socket) do
    format = String.to_existing_atom(format_str)

    {:noreply,
     socket
     |> assign(:format, format)
     |> push_patch(to: build_path(socket, format: format))}
  end

  @impl true
  def handle_event("param_changed", params, socket) do
    # Merge new parameter values
    updated_params = Map.merge(socket.assigns.parameters, params)

    # Validate parameters
    param_defs = socket.assigns.report_definition.parameters
    errors = validate_parameters(param_defs, updated_params)

    {:noreply,
     socket
     |> assign(:parameters, updated_params)
     |> assign(:parameter_errors, errors)}
  end

  @impl true
  def handle_event("run_report", _params, socket) do
    # Validate before running
    param_defs = socket.assigns.report_definition.parameters
    parameters = socket.assigns.parameters

    case ParameterForm.validate_all_parameters(param_defs, parameters) do
      {:ok, validated_params} ->
        {:noreply, execute_report(socket, validated_params)}

      {:error, errors} ->
        {:noreply,
         socket
         |> assign(:parameter_errors, errors)
         |> put_flash(:error, "Please fix parameter errors before running report")}
    end
  end

  @impl true
  def handle_event("retry_report", _params, socket) do
    retry_count = socket.assigns.retry_count + 1

    if retry_count <= socket.assigns.max_retries do
      {:noreply,
       socket
       |> assign(:retry_count, retry_count)
       |> execute_report(socket.assigns.parameters)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Maximum retry attempts reached")}
    end
  end

  @impl true
  def handle_event("edit_parameters", _params, socket) do
    {:noreply,
     socket
     |> assign(:result_state, :idle)
     |> assign(:result, nil)
     |> assign(:error, nil)
     |> clear_flash()}
  end

  @impl true
  def handle_event("reset_parameters", _params, socket) do
    default_params = get_default_parameters(socket.assigns.report_definition)

    {:noreply,
     socket
     |> assign(:parameters, default_params)
     |> assign(:parameter_errors, %{})
     |> assign(:result_state, :idle)
     |> assign(:result, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_info({:report_complete, {:ok, result}}, socket) do
    {:ok, processed_result} = ResultHandler.process({:ok, result})

    {:noreply,
     socket
     |> assign(:result_state, :success)
     |> assign(:result, processed_result)
     |> assign(:retry_count, 0)}
  end

  @impl true
  def handle_info({:report_error, error}, socket) do
    parsed_error = ResultHandler.parse_error(error)

    {:noreply,
     socket
     |> assign(:result_state, :error)
     |> assign(:error, parsed_error)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-4">
      <.link navigate={~p"/reports"} class="text-sm font-medium text-blue-600 hover:text-blue-500">
        ← Back to Reports
      </.link>
    </div>

    <.header>
      <%= @report_definition.title %>
      <:subtitle>
        <%= Map.get(@report_definition, :description, "Generate and view report with custom parameters") %>
      </:subtitle>
    </.header>

    <div class="mt-8 grid grid-cols-1 gap-8 lg:grid-cols-3">
      <!-- Left Column: Parameters and Controls -->
      <div class="lg:col-span-1 space-y-6">
        <!-- Format Selection -->
        <div class="bg-white shadow rounded-lg p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Output Format</h3>
          <select
            name="format"
            phx-change="format_changed"
            value={@format}
            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
          >
            <option value="html">HTML</option>
            <option value="json">JSON</option>
            <option value="heex">HEEX</option>
            <option value="pdf">PDF</option>
          </select>
          <p class="mt-2 text-xs text-gray-500">
            <%= format_description(@format) %>
          </p>
        </div>

        <!-- Parameters Form -->
        <div class="bg-white shadow rounded-lg p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Parameters</h3>
          <ParameterForm.parameter_form
            parameters={@report_definition.parameters}
            values={@parameters}
            errors={@parameter_errors}
            on_change="param_changed"
            disabled={@result_state == :loading}
          />
        </div>

        <!-- Action Buttons -->
        <div class="bg-white shadow rounded-lg p-6 space-y-3">
          <button
            type="button"
            phx-click="run_report"
            disabled={@result_state == :loading}
            class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-400 disabled:cursor-not-allowed"
          >
            <%= if @result_state == :loading do %>
              <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Generating...
            <% else %>
              Run Report
            <% end %>
          </button>

          <button
            type="button"
            phx-click="reset_parameters"
            disabled={@result_state == :loading}
            class="w-full inline-flex justify-center items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-100 disabled:cursor-not-allowed"
          >
            Reset to Defaults
          </button>
        </div>

        <!-- Report Metadata -->
        <div class="bg-white shadow rounded-lg p-6">
          <h3 class="text-sm font-medium text-gray-500 mb-3">Report Details</h3>
          <dl class="space-y-2 text-sm">
            <div>
              <dt class="text-gray-500">Parameters</dt>
              <dd class="text-gray-900 font-medium"><%= length(@report_definition.parameters) %></dd>
            </div>
            <div>
              <dt class="text-gray-500">Variables</dt>
              <dd class="text-gray-900 font-medium"><%= length(@report_definition.variables) %></dd>
            </div>
            <div>
              <dt class="text-gray-500">Groups</dt>
              <dd class="text-gray-900 font-medium"><%= length(@report_definition.groups) %></dd>
            </div>
          </dl>
        </div>
      </div>

      <!-- Right Column: Results -->
      <div class="lg:col-span-2">
        <%= case @result_state do %>
          <% :idle -> %>
            <div class="bg-gray-50 border-2 border-dashed border-gray-300 rounded-lg p-12 text-center">
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-gray-900">No report generated yet</h3>
              <p class="mt-1 text-sm text-gray-500">
                Configure parameters and click "Run Report" to generate
              </p>
            </div>

          <% :loading -> %>
            <div class="bg-white shadow rounded-lg p-12 text-center">
              <svg class="animate-spin mx-auto h-12 w-12 text-blue-600" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <h3 class="mt-4 text-lg font-medium text-gray-900">Generating Report</h3>
              <p class="mt-2 text-sm text-gray-500">
                Please wait while your report is being generated...
              </p>
            </div>

          <% :success -> %>
            <div class="bg-white shadow rounded-lg overflow-hidden">
              <!-- Result Header -->
              <div class="bg-gray-50 px-6 py-4 border-b border-gray-200">
                <div class="flex items-center justify-between">
                  <div>
                    <h3 class="text-lg font-medium text-gray-900">Report Results</h3>
                    <p class="mt-1 text-sm text-gray-500">
                      <%= ResultHandler.get_execution_summary(@result).summary_text %>
                    </p>
                  </div>
                  <%= if @format in [:pdf, :json] do %>
                    <button
                      type="button"
                      class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                    >
                      Download
                    </button>
                  <% end %>
                </div>
              </div>

              <!-- Result Content -->
              <div class="p-6">
                <%= render_result_content(@result, @format) %>
              </div>
            </div>

          <% :error -> %>
            <ReportError.report_error
              error={@error}
              retry_event="retry_report"
              show_technical_details={false}
              max_retries={@max_retries}
              retry_count={@retry_count}
            />
        <% end %>
      </div>
    </div>
    """
  end

  # Private functions

  defp initialize_viewer(socket, report_name, report_info) do
    default_params = get_default_parameters(report_info)

    socket
    |> assign(:page_title, report_info.title)
    |> assign(:report_name, report_name)
    |> assign(:report_definition, report_info)
    |> assign(:format, :html)
    |> assign(:parameters, default_params)
    |> assign(:parameter_errors, %{})
    |> assign(:result_state, :idle)
    |> assign(:result, nil)
    |> assign(:error, nil)
    |> assign(:max_retries, 3)
    |> assign(:retry_count, 0)
  end

  defp parse_format(nil), do: :html
  defp parse_format(format_str) when is_binary(format_str) do
    try do
      String.to_existing_atom(format_str)
    rescue
      ArgumentError -> :html
    end
  end

  defp parse_parameters(params) when is_map(params) do
    params
    |> Enum.filter(fn {key, _value} -> key not in ["format", "name", "auto_run"] end)
    |> Enum.into(%{}, fn {key, value} ->
      {String.to_existing_atom(key), value}
    end)
  rescue
    _ -> %{}
  end

  defp maybe_auto_run(socket, params) do
    if params["auto_run"] == "true" && socket.assigns.result_state == :idle do
      execute_report(socket, socket.assigns.parameters)
    else
      socket
    end
  end

  defp execute_report(socket, parameters) do
    parent = self()
    report_name = socket.assigns.report_name
    format = socket.assigns.format

    Task.start(fn ->
      result = PipelineClient.run_report(
        AshReportsDemo.Domain,
        report_name,
        parameters,
        format: format
      )

      case result do
        {:ok, report_result} ->
          send(parent, {:report_complete, {:ok, report_result}})

        {:error, error} ->
          send(parent, {:report_error, error})
      end
    end)

    socket
    |> assign(:result_state, :loading)
    |> assign(:result, nil)
    |> assign(:error, nil)
    |> clear_flash()
  end

  defp get_default_parameters(report_definition) do
    report_definition.parameters
    |> Enum.filter(fn param -> Map.has_key?(param, :default) end)
    |> Enum.into(%{}, fn param -> {param.name, param.default} end)
  end

  defp validate_parameters(param_defs, values) do
    case ParameterForm.validate_all_parameters(param_defs, values) do
      {:ok, _} -> %{}
      {:error, errors} -> errors
    end
  end

  defp build_path(socket, opts) do
    format = Keyword.get(opts, :format, socket.assigns.format)
    params = Map.merge(socket.assigns.parameters, %{format: format})

    params_str =
      params
      |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
      |> Enum.join("&")

    ~p"/reports/#{socket.assigns.report_name}?#{params_str}"
  end

  defp format_description(:html), do: "Interactive HTML view"
  defp format_description(:json), do: "Structured JSON data"
  defp format_description(:heex), do: "Phoenix LiveView component"
  defp format_description(:pdf), do: "Downloadable PDF document"
  defp format_description(_), do: ""

  defp render_result_content(result, :html) do
    assigns = %{result: result}

    ~H"""
    <AshReportsDemoWeb.Components.HtmlReportViewer.html_report_viewer
      content={@result.content}
      metadata={@result.metadata}
    />
    """
  end

  defp render_result_content(result, :json) do
    assigns = %{content: result.content}

    ~H"""
    <pre class="bg-gray-50 rounded-lg p-4 overflow-x-auto text-sm"><%= @content %></pre>
    """
  end

  defp render_result_content(result, :heex) do
    assigns = %{content: result.content}

    ~H"""
    <div class="report-heex-content bg-gray-50 rounded-lg p-4">
      <code class="text-sm"><%= @content %></code>
    </div>
    """
  end

  defp render_result_content(result, :pdf) do
    size_mb = byte_size(result.content) / 1_024 / 1_024

    assigns = %{
      size_mb: Float.round(size_mb, 2),
      report_name: result.metadata[:report_name] || "report"
    }

    ~H"""
    <div class="text-center py-8">
      <svg class="mx-auto h-16 w-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">PDF Generated</h3>
      <p class="mt-1 text-sm text-gray-500">
        Size: <%= @size_mb %> MB
      </p>
      <div class="mt-6">
        <a
          href={~p"/reports/#{@report_name}/pdf"}
          download
          class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
        >
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
          </svg>
          Download PDF
        </a>
      </div>
    </div>
    """
  end
end
