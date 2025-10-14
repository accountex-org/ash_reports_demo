defmodule AshReportsDemoWeb.Reports.PipelineClient do
  @moduledoc """
  Client wrapper for `AshReports.Runner` that provides a clean API for LiveView
  components to execute reports through the full pipeline.

  This module handles:
  - Report execution through the three-stage pipeline (DataLoader → RenderContext → RenderPipeline)
  - Format validation and selection
  - Parameter validation
  - Progress tracking for streaming reports
  - Timeout and cancellation support
  - Result normalization across different formats

  ## Examples

      # Execute a report with default format (HTML)
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{region: "CA"}
      )

      # Execute with specific format
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :financial_summary,
        %{},
        format: :pdf
      )

      # Execute asynchronously
      {:ok, task} = PipelineClient.run_report_async(
        AshReportsDemo.Domain,
        :invoice_details,
        %{status: "paid"}
      )

  """

  require Logger

  @valid_formats [:html, :pdf, :json, :heex]
  @default_timeout 30_000  # 30 seconds

  @doc """
  Execute a report through the pipeline with the specified parameters and format.

  ## Parameters
    * `domain` - The Ash domain module containing the report definition
    * `report_name` - The atom name of the report to execute
    * `params` - Map of parameters to pass to the report
    * `opts` - Keyword list of options:
      * `:format` - Output format (default: `:html`)
      * `:timeout` - Execution timeout in milliseconds (default: 30000)
      * `:streaming` - Enable streaming mode (default: `false`)

  ## Returns
    * `{:ok, result}` - Successfully executed report with normalized result
    * `{:error, reason}` - Execution failed with error information

  ## Examples

      iex> PipelineClient.run_report(MyApp.Domain, :my_report, %{param: "value"})
      {:ok, %{content: "...", metadata: %{...}, format: :html}}

      iex> PipelineClient.run_report(MyApp.Domain, :my_report, %{}, format: :pdf)
      {:ok, %{content: <<...>>, metadata: %{...}, format: :pdf}}

  """
  def run_report(domain, report_name, params, opts \\ []) do
    format = Keyword.get(opts, :format, :html)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    with :ok <- validate_format(format),
         :ok <- validate_parameters(domain, report_name, params),
         {:ok, result} <- execute_pipeline(domain, report_name, params, format, timeout) do
      {:ok, normalize_result(result, format)}
    end
  end

  @doc """
  Execute a report asynchronously in a background task.

  Returns a `Task` struct that can be awaited or monitored.

  ## Examples

      {:ok, task} = PipelineClient.run_report_async(MyApp.Domain, :my_report, %{})
      result = Task.await(task, :infinity)

  """
  def run_report_async(domain, report_name, params, opts \\ []) do
    task = Task.async(fn ->
      run_report(domain, report_name, params, opts)
    end)

    {:ok, task}
  end

  @doc """
  Execute a report with progress tracking callbacks for streaming reports.

  The callback function receives progress updates as they occur.

  ## Parameters
    * `domain` - The Ash domain module
    * `report_name` - The report to execute
    * `params` - Report parameters
    * `callback_pid` - PID to receive progress messages
    * `opts` - Additional options

  ## Progress Messages

  The callback PID will receive messages in the format:
  `{:progress, %{records_processed: integer, total_records: integer, percentage: float}}`

  ## Examples

      PipelineClient.run_report_with_progress(
        MyApp.Domain,
        :large_report,
        %{},
        self()
      )

      # In the receiving process:
      receive do
        {:progress, progress} -> IO.inspect(progress)
      end

  """
  def run_report_with_progress(domain, report_name, params, callback_pid, opts \\ []) do
    opts = Keyword.merge(opts, [
      streaming: true,
      progress_callback: fn progress ->
        send(callback_pid, {:progress, progress})
      end
    ])

    run_report(domain, report_name, params, opts)
  end

  @doc """
  Validate parameters against the report definition.

  ## Returns
    * `:ok` - Parameters are valid
    * `{:error, reason}` - Parameters are invalid

  """
  def validate_parameters(domain, report_name, params) do
    case get_report_info(domain, report_name) do
      {:ok, report_info} ->
        validate_params_against_definition(params, report_info.parameters)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get report metadata and definition from the domain.

  ## Returns
    * `{:ok, report_info}` - Report metadata including parameters, variables, bands, and groups
    * `{:error, :report_not_found}` - Report does not exist in domain

  """
  def get_report_info(domain, report_name) do
    case AshReports.Info.report(domain, report_name) do
      nil -> {:error, :report_not_found}
      report -> {:ok, report}
    end
  end

  # Private functions

  defp validate_format(format) when format in @valid_formats, do: :ok
  defp validate_format(format) do
    {:error, "Invalid format: #{inspect(format)}. Valid formats: #{inspect(@valid_formats)}"}
  end

  defp execute_pipeline(domain, report_name, params, format, timeout) do
    task = Task.async(fn ->
      AshReports.Runner.run_report(domain, report_name, params, format: format)
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} ->
        result

      nil ->
        Logger.warning("Report execution timed out",
          domain: domain,
          report: report_name,
          timeout: timeout
        )
        {:error, %{stage: :execution, reason: :timeout}}

      {:exit, reason} ->
        Logger.error("Report execution crashed",
          domain: domain,
          report: report_name,
          reason: reason
        )
        {:error, %{stage: :execution, reason: {:exit, reason}}}
    end
  end

  defp normalize_result(result, format) do
    %{
      content: result.content,
      metadata: normalize_metadata(result.metadata),
      format: format,
      status: :success
    }
  end

  defp normalize_metadata(metadata) when is_map(metadata) do
    %{
      execution_time_ms: Map.get(metadata, :execution_time_ms, 0),
      record_count: Map.get(metadata, :record_count, 0),
      stages_executed: Map.get(metadata, :stages_executed, []),
      pipeline_version: Map.get(metadata, :pipeline_version, "unknown")
    }
  end

  defp normalize_metadata(_), do: %{}

  defp normalize_error(%{stage: stage, reason: reason}) do
    %{
      stage: stage,
      reason: reason,
      message: format_error_message(stage, reason)
    }
  end

  defp normalize_error(reason) when is_binary(reason) do
    %{
      stage: :unknown,
      reason: reason,
      message: reason
    }
  end

  defp normalize_error(reason) do
    %{
      stage: :unknown,
      reason: reason,
      message: "An unexpected error occurred: #{inspect(reason)}"
    }
  end

  defp format_error_message(:data_loading, reason) do
    "Failed to load report data: #{format_reason(reason)}. " <>
    "Please check that the report exists and all parameters are valid."
  end

  defp format_error_message(:context_building, reason) do
    "Failed to build render context: #{format_reason(reason)}. " <>
    "The data loaded successfully but context preparation failed."
  end

  defp format_error_message(:rendering, reason) do
    "Failed to render report: #{format_reason(reason)}. " <>
    "The data loaded successfully but rendering failed."
  end

  defp format_error_message(:execution, :timeout) do
    "Report execution timed out. The report may be too complex or the data set too large."
  end

  defp format_error_message(stage, reason) do
    "Error in #{stage} stage: #{format_reason(reason)}"
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason({:exit, reason}), do: "Process crashed: #{inspect(reason)}"
  defp format_reason(reason), do: inspect(reason)

  defp validate_params_against_definition(params, parameter_defs) do
    # Get required parameter names
    required_params = Enum.filter(parameter_defs, fn param ->
      # Check if parameter has no default value (making it required)
      !Map.has_key?(param, :default)
    end)
    |> Enum.map(& &1.name)

    # Check all required parameters are present
    missing_params = required_params -- Map.keys(params)

    if Enum.empty?(missing_params) do
      :ok
    else
      {:error, "Missing required parameters: #{inspect(missing_params)}"}
    end
  end
end
