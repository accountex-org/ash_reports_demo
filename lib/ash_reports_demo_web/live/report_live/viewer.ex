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
  alias AshReportsDemoWeb.Components.{ParameterForm, ReportError, ReportTemplateViewer}

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
  def handle_event("format_changed", params, socket) when is_map(params) do
    format_str = params["format"] || socket.assigns.format |> to_string()
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
    param_defs = socket.assigns.report_definition.parameters
    parameters = socket.assigns.parameters

    case ParameterForm.validate_all_parameters(param_defs, parameters) do
      {:ok, validated_params} ->
        path = build_path(socket, format: socket.assigns.format, params: validated_params)

        {:noreply,
         socket
         |> push_patch(to: path)
         |> execute_report(validated_params)}

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
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    active_tab = String.to_existing_atom(tab)
    {:noreply, assign(socket, :active_tab, active_tab)}
  end

  @impl true
  def handle_info({:report_complete, {:ok, result}}, socket) do
    {:ok, processed_result} = ResultHandler.process({:ok, result})

    socket =
      if socket.assigns.report_timeout_ref do
        Process.cancel_timer(socket.assigns.report_timeout_ref)
        assign(socket, :report_timeout_ref, nil)
      else
        socket
      end

    processed_result =
      if socket.assigns.format == :pdf do
        pdf_size = if is_binary(processed_result.content), do: byte_size(processed_result.content), else: 0
        
        case AshReportsDemoWeb.PdfStore.store_pdf(
          processed_result.content,
          %{
            filename: "#{socket.assigns.report_name}_#{Date.utc_today()}.pdf",
            report_name: socket.assigns.report_name,
            generated_at: DateTime.utc_now()
          }
        ) do
          {:ok, pdf_id} ->
            updated_metadata = Map.put(processed_result.metadata, :size_bytes, pdf_size)
            
            processed_result
            |> Map.put(:pdf_id, pdf_id)
            |> Map.put(:content, :pdf_stored)
            |> Map.put(:metadata, updated_metadata)
          
          _error ->
            processed_result
        end
      else
        processed_result
      end

    {:noreply,
     socket
     |> assign(:result_state, :success)
     |> assign(:result, processed_result)
     |> assign(:retry_count, 0)}
  end

  @impl true
  def handle_info({:report_error, error}, socket) do
    parsed_error = ResultHandler.parse_error(error)

    socket =
      if socket.assigns.report_timeout_ref do
        Process.cancel_timer(socket.assigns.report_timeout_ref)
        assign(socket, :report_timeout_ref, nil)
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:result_state, :error)
     |> assign(:error, parsed_error)}
  end

  @impl true
  def handle_info(:report_timeout, socket) do
    {:noreply,
     socket
     |> assign(:result_state, :error)
     |> assign(:report_timeout_ref, nil)
     |> assign(:error, %{
       stage: :execution,
       type: :timeout,
       reason: :timeout,
       user_message: "Report generation timed out after 30 seconds",
       suggested_action: "Try running the report with fewer parameters or a smaller dataset. If the problem persists, there may be an issue with the report configuration.",
       technical_details: "The report execution exceeded the 30 second timeout limit.",
       recoverable: true
     })}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-4">
      <.link navigate={~p"/reports"} class="text-sm font-medium text-white hover:text-[#B4C6E7]">
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
          <form phx-change="format_changed">
            <select
              name="format"
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-[#4472C4] focus:ring-[#4472C4] sm:text-sm"
            >
              <option value="pdf" selected={@format == :pdf}>PDF</option>
              <option value="html" selected={@format == :html}>HTML</option>
              <option value="json" selected={@format == :json}>JSON</option>
              <option value="heex" selected={@format == :heex}>HEEX</option>
            </select>
          </form>
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
            class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-[#4472C4] hover:bg-[#2F5597] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#4472C4] disabled:bg-gray-400 disabled:cursor-not-allowed"
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
            class="w-full inline-flex justify-center items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-[#B4C6E7] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#4472C4] disabled:bg-gray-100 disabled:cursor-not-allowed"
          >
            Reset to Defaults
          </button>
        </div>

        <!-- Report Metadata -->
        <div class="bg-white shadow rounded-lg p-6">
          <h3 class="text-sm font-medium text-gray-500 mb-3">Report Details</h3>
          <dl class="space-y-3 sm:space-y-0 sm:grid sm:grid-cols-3 sm:gap-4 text-sm">
            <div class="sm:text-center">
              <dt class="text-gray-500 mb-1">Parameters</dt>
              <dd class="text-gray-900 font-medium text-lg"><%= length(@report_definition.parameters) %></dd>
            </div>
            <div class="sm:text-center">
              <dt class="text-gray-500 mb-1">Variables</dt>
              <dd class="text-gray-900 font-medium text-lg"><%= length(@report_definition.variables) %></dd>
            </div>
            <div class="sm:text-center">
              <dt class="text-gray-500 mb-1">Groups</dt>
              <dd class="text-gray-900 font-medium text-lg"><%= length(@report_definition.groups) %></dd>
            </div>
          </dl>
        </div>
      </div>

      <!-- Right Column: Tabbed Content -->
      <div class="lg:col-span-2">
        <!-- Tab Navigation -->
        <div class="bg-white shadow rounded-t-lg">
          <div class="border-b border-gray-200">
            <nav class="-mb-px flex" aria-label="Tabs">
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="preview"
                class={
                  [
                    "w-1/3 py-4 px-1 text-center border-b-2 font-medium text-sm",
                    @active_tab == :preview && "border-[#4472C4] text-[#4472C4]",
                    @active_tab != :preview && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                  ]
                }
              >
                Report Preview
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="code"
                class={
                  [
                    "w-1/3 py-4 px-1 text-center border-b-2 font-medium text-sm",
                    @active_tab == :code && "border-[#4472C4] text-[#4472C4]",
                    @active_tab != :code && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                  ]
                }
              >
                Generated Code
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="template"
                class={
                  [
                    "w-1/3 py-4 px-1 text-center border-b-2 font-medium text-sm",
                    @active_tab == :template && "border-[#4472C4] text-[#4472C4]",
                    @active_tab != :template && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                  ]
                }
              >
                Report Template (Spark DSL)
              </button>
            </nav>
          </div>
        </div>

        <!-- Tab Content -->
        <div class="bg-white shadow rounded-b-lg" style="min-height: 500px;">
          <%= if @active_tab == :preview do %>
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
                <%= render_preview_content(@result, @format) %>
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
      <% end %>
      
      <%= if @active_tab == :code do %>
        <%= case @result_state do %>
          <% :idle -> %>
            <div class="bg-gray-50 border-2 border-dashed border-gray-300 rounded-lg p-12 text-center">
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-gray-900">No code generated yet</h3>
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
              <h3 class="mt-4 text-lg font-medium text-gray-900">Generating Code</h3>
              <p class="mt-2 text-sm text-gray-500">
                Please wait while your code is being generated...
              </p>
            </div>

          <% :success -> %>
            <div class="bg-white shadow rounded-lg overflow-hidden">
              <div class="bg-gray-50 px-6 py-4 border-b border-gray-200">
                <div class="flex items-center justify-between">
                  <div>
                    <h3 class="text-lg font-medium text-gray-900">Generated Code</h3>
                    <p class="mt-1 text-sm text-gray-500">
                      <%= ResultHandler.get_execution_summary(@result).summary_text %>
                    </p>
                  </div>
                </div>
              </div>
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
      <% end %>
      
      <%= if @active_tab == :template do %>
        <!-- Template Tab Content -->
        <div class="p-6">
          <ReportTemplateViewer.report_template_viewer
            report_name={@report_name}
            domain={AshReportsDemo.Domain}
          />
        </div>
      <% end %>
        </div>
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
    |> assign(:format, :pdf)
    |> assign(:parameters, default_params)
    |> assign(:parameter_errors, %{})
    |> assign(:result_state, :idle)
    |> assign(:result, nil)
    |> assign(:error, nil)
    |> assign(:max_retries, 3)
    |> assign(:retry_count, 0)
    |> assign(:active_tab, :preview)
    |> assign(:report_timeout_ref, nil)
  end

  defp parse_format(nil), do: :pdf

  defp parse_format(format_str) when is_binary(format_str) do
    String.to_existing_atom(format_str)
  rescue
    ArgumentError -> :html
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

    socket =
      if socket.assigns.report_timeout_ref do
        Process.cancel_timer(socket.assigns.report_timeout_ref)
        socket
      else
        socket
      end

    timeout_ref = Process.send_after(self(), :report_timeout, 30_000)

    Task.start(fn ->
      try do
        result =
          PipelineClient.run_report(
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
      rescue
        error ->
          send(parent, {:report_error, %{
            type: :exception,
            message: Exception.message(error),
            details: Exception.format(:error, error)
          }})
      catch
        kind, reason ->
          send(parent, {:report_error, %{
            type: kind,
            message: "Report generation failed",
            details: inspect(reason)
          }})
      end
    end)

    socket
    |> assign(:result_state, :loading)
    |> assign(:result, nil)
    |> assign(:error, nil)
    |> assign(:report_timeout_ref, timeout_ref)
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
    custom_params = Keyword.get(opts, :params, %{})

    params =
      socket.assigns.parameters
      |> Map.merge(custom_params)
      |> Map.put(:format, format)
      |> Enum.reject(fn {_key, value} -> value == nil || value == "" end)
      |> Enum.map(fn {key, value} -> {to_string(key), to_string(value)} end)
      |> Enum.into(%{})

    ~p"/reports/#{socket.assigns.report_name}?#{params}"
  end

  defp format_description(:html), do: "Interactive HTML view"
  defp format_description(:json), do: "Structured JSON data"
  defp format_description(:heex), do: "Phoenix LiveView component"
  defp format_description(:pdf), do: "Downloadable PDF document"
  defp format_description(_), do: ""

  defp render_preview_content(result, :html) do
    assigns = %{result: result}

    ~H"""
    <AshReportsDemoWeb.Components.HtmlReportViewer.html_report_viewer
      content={@result.content}
      metadata={@result.metadata}
    />
    """
  end

  defp render_preview_content(result, :heex) do
    heex_content = result.content
    
    assigns = %{
      heex_content: heex_content,
      supports_charts: false,
      reports: [],
      locale: "en"
    }

    ~H"""
    <div class="report-preview-heex">
      <%= render_heex_template(@heex_content, assigns) %>
    </div>
    """
  end

  defp render_preview_content(result, :json) do
    formatted_json = format_json(result.content)
    assigns = %{content: formatted_json}

    ~H"""
    <div class="bg-gray-50 rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">JSON Data Preview</h3>
      <pre class="bg-white border border-gray-200 rounded p-4 overflow-auto text-sm font-mono" style="max-height: 500px;"><%= @content %></pre>
    </div>
    """
  end

  defp render_preview_content(result, :pdf) do
    pdf_id = Map.get(result, :pdf_id)
    
    {size_value, size_unit} =
      if pdf_id do
        case AshReportsDemoWeb.PdfStore.get_pdf(pdf_id) do
          {:ok, entry} ->
            bytes = entry.size_bytes
            if bytes < 1_024 * 100 do
              {Float.round(bytes / 1_024, 1), "KB"}
            else
              {Float.round(bytes / 1_024 / 1_024, 2), "MB"}
            end
          _ -> {0.0, "MB"}
        end
      else
        bytes = result.metadata[:size_bytes] || 0
        if bytes < 1_024 * 100 do
          {Float.round(bytes / 1_024, 1), "KB"}
        else
          {Float.round(bytes / 1_024 / 1_024, 2), "MB"}
        end
      end

    assigns = %{
      size_value: size_value,
      size_unit: size_unit,
      pdf_id: pdf_id,
      report_name: result.metadata[:report_name] || "report",
      has_pdf: pdf_id != nil
    }

    ~H"""
    <div class="space-y-6">
      <%= if @has_pdf do %>
        <div class="bg-white rounded-lg border border-gray-200 overflow-hidden" style="height: 600px;">
          <iframe
            src={~p"/pdf/#{@pdf_id}/view"}
            class="w-full h-full"
            title="PDF Preview"
          >
          </iframe>
        </div>
        
        <div class="flex justify-center gap-4">
          <a
            href={~p"/pdf/#{@pdf_id}/download"}
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-[#4472C4] hover:bg-[#2F5597] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#4472C4]"
          >
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Download PDF (<%= @size_value %> <%= @size_unit %>)
          </a>
          
          <a
            href={~p"/pdf/#{@pdf_id}/view"}
            target="_blank"
            class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#4472C4]"
          >
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
            </svg>
            Open in New Tab
          </a>
        </div>
      <% else %>
        <div class="text-center py-8">
          <svg class="mx-auto h-16 w-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">PDF Generated</h3>
          <p class="mt-1 text-sm text-gray-500">
            Size: <%= @size_value %> <%= @size_unit %>
          </p>
          <p class="mt-2 text-xs text-gray-400">
            PDF expired or unavailable
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_result_content(result, :html) do
    assigns = %{content: result.content}

    ~H"""
    <div>
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">
          Generated HTML Output
        </h3>
        <button
          type="button"
          phx-click={JS.dispatch("phx:copy", to: "#generated-html-wrapper")}
          class="inline-flex items-center px-3 py-1 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
        >
          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
          </svg>
          Copy
        </button>
      </div>

      <div id="generated-html-wrapper" phx-hook="CopyToClipboard" class="relative" style="max-height: 600px; overflow-y: auto;">
        <pre
          id="generated-html-code"
          phx-hook="HighlightCode"
          class="bg-gray-900 text-gray-100 rounded-lg p-4 overflow-x-auto text-sm font-mono leading-relaxed"
        ><code class="language-elixir" phx-no-format><%= @content %></code></pre>
      </div>
    </div>
    """
  end

  defp render_result_content(result, :json) do
    formatted_json = format_json(result.content)
    assigns = %{content: formatted_json}

    ~H"""
    <div>
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">
          Generated JSON Output
        </h3>
        <button
          type="button"
          phx-click={JS.dispatch("phx:copy", to: "#generated-json-wrapper")}
          class="inline-flex items-center px-3 py-1 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
        >
          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
          </svg>
          Copy
        </button>
      </div>

      <div id="generated-json-wrapper" phx-hook="CopyToClipboard" class="relative" style="max-height: 600px; overflow-y: auto;">
        <pre
          id="generated-json-code"
          phx-hook="HighlightCode"
          class="bg-gray-900 text-gray-100 rounded-lg p-4 overflow-x-auto text-sm font-mono leading-relaxed"
        ><code class="language-json" phx-no-format><%= @content %></code></pre>
      </div>
    </div>
    """
  end

  defp render_result_content(result, :heex) do
    assigns = %{content: result.content}

    ~H"""
    <div>
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">
          Generated HEEX Output
        </h3>
        <button
          type="button"
          phx-click={JS.dispatch("phx:copy", to: "#generated-heex-wrapper")}
          class="inline-flex items-center px-3 py-1 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
        >
          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
          </svg>
          Copy
        </button>
      </div>

      <div id="generated-heex-wrapper" phx-hook="CopyToClipboard" class="relative" style="max-height: 600px; overflow-y: auto;">
        <pre
          id="generated-heex-code"
          phx-hook="HighlightCode"
          class="bg-gray-900 text-gray-100 rounded-lg p-4 overflow-x-auto text-sm font-mono leading-relaxed"
        ><code class="language-elixir" phx-no-format><%= @content %></code></pre>
      </div>
    </div>
    """
  end

  defp render_result_content(result, :pdf) do
    pdf_id = Map.get(result, :pdf_id)
    
    {size_value, size_unit} =
      if pdf_id do
        case AshReportsDemoWeb.PdfStore.get_pdf(pdf_id) do
          {:ok, entry} ->
            bytes = entry.size_bytes
            if bytes < 1_024 * 100 do
              {Float.round(bytes / 1_024, 1), "KB"}
            else
              {Float.round(bytes / 1_024 / 1_024, 2), "MB"}
            end
          _ -> {0.0, "MB"}
        end
      else
        bytes = result.metadata[:size_bytes] || 0
        if bytes < 1_024 * 100 do
          {Float.round(bytes / 1_024, 1), "KB"}
        else
          {Float.round(bytes / 1_024 / 1_024, 2), "MB"}
        end
      end

    assigns = %{
      size_value: size_value,
      size_unit: size_unit,
      pdf_id: pdf_id,
      report_name: result.metadata[:report_name] || "report",
      has_pdf: pdf_id != nil
    }

    ~H"""
    <div class="space-y-6">
      <%= if @has_pdf do %>
        <div class="bg-white rounded-lg border border-gray-200 overflow-hidden" style="height: 600px;">
          <iframe
            src={~p"/pdf/#{@pdf_id}/view"}
            class="w-full h-full"
            title="PDF Preview"
          >
          </iframe>
        </div>
        
        <div class="flex justify-center gap-4">
          <a
            href={~p"/pdf/#{@pdf_id}/download"}
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-[#4472C4] hover:bg-[#2F5597] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#4472C4]"
          >
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Download PDF (<%= @size_value %> <%= @size_unit %>)
          </a>
          
          <a
            href={~p"/pdf/#{@pdf_id}/view"}
            target="_blank"
            class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#4472C4]"
          >
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
            </svg>
            Open in New Tab
          </a>
        </div>
      <% else %>
        <div class="text-center py-8">
          <svg class="mx-auto h-16 w-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">PDF Generated</h3>
          <p class="mt-1 text-sm text-gray-500">
            Size: <%= @size_value %> <%= @size_unit %>
          </p>
          <p class="mt-2 text-xs text-gray-400">
            PDF expired or unavailable
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_json(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, decoded} ->
        Jason.encode!(decoded, pretty: true)

      {:error, _} ->
        json_string
    end
  rescue
    _ -> json_string
  end

  defp format_json(data) do
    Jason.encode!(data, pretty: true)
  rescue
    _ -> inspect(data)
  end

  defp render_heex_template(heex_string, template_assigns) do
    opts = [
      engine: Phoenix.LiveView.TagEngine,
      line: 1,
      file: "dynamic.heex",
      caller: __ENV__,
      source: heex_string,
      tag_handler: Phoenix.LiveView.HTMLEngine
    ]
    
    compiled = EEx.compile_string(heex_string, opts)
    
    {result, _bindings} = Code.eval_quoted(compiled, [assigns: template_assigns], __ENV__)
    
    result
  rescue
    error ->
      error_message = Exception.message(error)
      {:safe, [
        ~s(<div class="bg-red-50 border border-red-200 rounded-lg p-4">),
        ~s(<h3 class="text-red-900 font-semibold mb-2">HEEX Rendering Error</h3>),
        ~s(<p class="text-red-700 text-sm">Unable to render HEEX template: ),
        error_message,
        ~s(</p></div>)
      ]}
  end
end
