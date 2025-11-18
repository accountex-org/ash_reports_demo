defmodule AshReportsDemoWeb.Reports.ResultHandler do
  @moduledoc """
  Process and transform pipeline results for display in the UI.

  This module handles:
  - Metadata extraction from pipeline results
  - Error formatting with stage context
  - Content formatting for different display types
  - Human-readable execution summaries
  - Result caching and metadata management

  ## Examples

      # Process a successful result
      {:ok, processed} = ResultHandler.process(pipeline_result)

      # Extract metadata
      metadata = ResultHandler.extract_metadata(result)

      # Format for display
      display_content = ResultHandler.format_for_display(result, :html)

      # Get execution summary
      summary = ResultHandler.get_execution_summary(result)

  """

  @doc """
  Main result processing function that normalizes pipeline results for UI display.

  ## Parameters
    * `result` - The raw result from PipelineClient

  ## Returns
    * `{:ok, processed_result}` - Processed result ready for display
    * `{:error, processed_error}` - Processed error with user-friendly information

  """
  def process({:ok, result}) do
    {:ok,
     %{
       content: result.content,
       metadata: extract_metadata(result),
       display: build_display_info(result),
       format: result.format,
       status: :success
     }}
  end

  def process({:error, error}) do
    {:error, parse_error(error)}
  end

  @doc """
  Extract pipeline metadata from a successful result.

  ## Returns
  A map containing:
    * `:execution_time_ms` - Time taken to execute the report
    * `:record_count` - Number of records processed
    * `:stages_executed` - List of pipeline stages that completed
    * `:pipeline_version` - Version of the pipeline used
    * `:format` - Output format
    * `:size_bytes` - Size of the generated content
    * Plus all other metadata from the original result (e.g., `:typst_template` for PDFs)

  """
  def extract_metadata(result) do
    # Preserve all original metadata and add/ensure standard fields
    base_metadata = result.metadata || %{}

    base_metadata
    |> Map.put_new(:execution_time_ms, 0)
    |> Map.put_new(:record_count, 0)
    |> Map.put_new(:stages_executed, [])
    |> Map.put_new(:pipeline_version, "unknown")
    |> Map.put(:format, result.format)
    |> Map.put(:size_bytes, calculate_size(result.content, result.format))
  end

  @doc """
  Format result content for specific display type.

  ## Parameters
    * `result` - The processed result
    * `display_type` - How to format the content (`:inline`, `:download`, `:preview`)

  ## Returns
  Formatted content appropriate for the display type

  """
  def format_for_display(result, display_type \\ :inline)

  def format_for_display(%{format: :html, content: content}, :inline) do
    # HTML content can be rendered directly with proper escaping
    %{
      type: :html,
      content: content,
      # Requires escaping in template
      safe: false
    }
  end

  def format_for_display(%{format: :pdf, content: content}, :download) do
    # PDF should be offered as download
    %{
      type: :download,
      content: content,
      mime_type: "application/pdf",
      filename: generate_filename(:pdf),
      size: byte_size(content)
    }
  end

  def format_for_display(%{format: :json, content: content}, :inline) do
    # JSON should be pretty-printed for display
    %{
      type: :code,
      content: prettify_json(content),
      language: "json"
    }
  end

  def format_for_display(%{format: :heex, content: content}, :inline) do
    # HEEX content for component rendering
    %{
      type: :component,
      content: content
    }
  end

  def format_for_display(result, _display_type) do
    # Fallback for unknown combinations
    %{
      type: :raw,
      content: inspect(result.content)
    }
  end

  @doc """
  Create a human-readable summary of the execution.

  ## Returns
  A map containing:
    * `:summary_text` - One-line summary
    * `:details` - List of detail strings
    * `:performance` - Performance metrics

  """
  def get_execution_summary(result) do
    metadata = extract_metadata(result)

    %{
      summary_text: build_summary_text(metadata),
      details: build_detail_list(metadata),
      performance: build_performance_metrics(metadata)
    }
  end

  @doc """
  Parse pipeline error with stage context and suggested actions.

  ## Returns
  A map containing:
    * `:stage` - The pipeline stage where error occurred
    * `:reason` - The error reason
    * `:user_message` - User-friendly error message
    * `:suggested_action` - Recommended next step
    * `:technical_details` - Full error details (for debugging)

  """
  def parse_error(%{stage: stage, reason: reason, message: message}) do
    %{
      stage: stage,
      reason: reason,
      user_message: message,
      suggested_action: suggest_action_for_stage(stage),
      technical_details: format_technical_details(stage, reason)
    }
  end

  def parse_error(error) when is_binary(error) do
    %{
      stage: :unknown,
      reason: :error,
      user_message: error,
      suggested_action: "Please check the error message and try again.",
      technical_details: error
    }
  end

  def parse_error(error) do
    %{
      stage: :unknown,
      reason: :unexpected_error,
      user_message: "An unexpected error occurred.",
      suggested_action: "Please contact support if the problem persists.",
      technical_details: inspect(error)
    }
  end

  # Private functions

  defp calculate_size(content, :pdf) when is_binary(content), do: byte_size(content)
  defp calculate_size(content, :html) when is_binary(content), do: byte_size(content)
  defp calculate_size(content, :json) when is_binary(content), do: byte_size(content)
  defp calculate_size(content, :heex) when is_binary(content), do: byte_size(content)
  defp calculate_size(_content, _format), do: 0

  defp build_display_info(result) do
    metadata = extract_metadata(result)

    %{
      title: "Report Generated Successfully",
      subtitle: format_timestamp(),
      summary:
        "#{metadata.record_count} records processed in #{format_duration(metadata.execution_time_ms)}"
    }
  end

  defp build_summary_text(metadata) do
    "#{metadata.record_count} records processed in #{format_duration(metadata.execution_time_ms)}"
  end

  defp build_detail_list(metadata) do
    [
      "Format: #{String.upcase(to_string(metadata.format))}",
      "Records: #{metadata.record_count}",
      "Execution time: #{format_duration(metadata.execution_time_ms)}",
      "Size: #{format_bytes(metadata.size_bytes)}",
      "Pipeline version: #{metadata.pipeline_version}"
    ]
  end

  defp build_performance_metrics(metadata) do
    records_per_second =
      if metadata.execution_time_ms > 0 do
        (metadata.record_count * 1000 / metadata.execution_time_ms)
        |> Float.round(2)
      else
        0
      end

    %{
      execution_time_ms: metadata.execution_time_ms,
      record_count: metadata.record_count,
      records_per_second: records_per_second,
      size_bytes: metadata.size_bytes
    }
  end

  defp suggest_action_for_stage(:data_loading) do
    "Verify that the report exists and all required parameters are provided with valid values."
  end

  defp suggest_action_for_stage(:context_building) do
    "The data loaded successfully. This may be a configuration issue with the report definition."
  end

  defp suggest_action_for_stage(:rendering) do
    "The data loaded successfully. Try a different output format or check the report template."
  end

  defp suggest_action_for_stage(:execution) do
    "The report may be too complex or taking too long. Try reducing the data set or increasing the timeout."
  end

  defp suggest_action_for_stage(_stage) do
    "Review the error details and try again. Contact support if the problem persists."
  end

  defp format_technical_details(stage, reason) do
    """
    Stage: #{stage}
    Reason: #{inspect(reason)}
    """
  end

  defp prettify_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, decoded} -> Jason.encode!(decoded, pretty: true)
      {:error, _} -> json
    end
  end

  defp prettify_json(data) do
    Jason.encode!(data, pretty: true)
  rescue
    _ -> inspect(data)
  end

  defp generate_filename(format) do
    timestamp =
      DateTime.utc_now()
      |> DateTime.to_unix()

    "report_#{timestamp}.#{format}"
  end

  defp format_timestamp do
    DateTime.utc_now()
    |> DateTime.to_string()
  end

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"

  defp format_duration(ms) when ms < 60_000 do
    seconds = Float.round(ms / 1000, 2)
    "#{seconds}s"
  end

  defp format_duration(ms) do
    minutes = div(ms, 60_000)
    seconds = div(rem(ms, 60_000), 1000)
    "#{minutes}m #{seconds}s"
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"

  defp format_bytes(bytes) when bytes < 1024 * 1024 do
    kb = Float.round(bytes / 1024, 2)
    "#{kb}KB"
  end

  defp format_bytes(bytes) do
    mb = Float.round(bytes / (1024 * 1024), 2)
    "#{mb}MB"
  end
end
