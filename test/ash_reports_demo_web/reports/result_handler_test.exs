defmodule AshReportsDemoWeb.Reports.ResultHandlerTest do
  use ExUnit.Case, async: true

  alias AshReportsDemoWeb.Reports.ResultHandler

  describe "process/1" do
    test "processes successful result" do
      result = %{
        content: "<html>Test Report</html>",
        metadata: %{
          execution_time_ms: 1234,
          record_count: 100
        },
        format: :html,
        status: :success
      }

      {:ok, processed} = ResultHandler.process({:ok, result})

      assert processed.status == :success
      assert processed.content == result.content
      assert processed.format == :html
      assert is_map(processed.metadata)
      assert is_map(processed.display)
    end

    test "processes error result" do
      error = %{
        stage: :data_loading,
        reason: :invalid_parameters,
        message: "Failed to load data"
      }

      {:error, processed} = ResultHandler.process({:error, error})

      assert processed.stage == :data_loading
      assert is_binary(processed.user_message)
      assert is_binary(processed.suggested_action)
    end
  end

  describe "extract_metadata/1" do
    test "extracts complete metadata" do
      result = %{
        content: "test content",
        metadata: %{
          execution_time_ms: 1500,
          record_count: 250,
          stages_executed: [:data_loading, :context_building, :rendering],
          pipeline_version: "1.0.0"
        },
        format: :html
      }

      metadata = ResultHandler.extract_metadata(result)

      assert metadata.execution_time_ms == 1500
      assert metadata.record_count == 250
      assert metadata.stages_executed == [:data_loading, :context_building, :rendering]
      assert metadata.pipeline_version == "1.0.0"
      assert metadata.format == :html
      assert is_integer(metadata.size_bytes)
    end

    test "handles missing metadata fields with defaults" do
      result = %{
        content: "test",
        metadata: %{},
        format: :json
      }

      metadata = ResultHandler.extract_metadata(result)

      assert metadata.execution_time_ms == 0
      assert metadata.record_count == 0
      assert metadata.stages_executed == []
      assert metadata.pipeline_version == "unknown"
    end

    test "calculates size for different formats" do
      content = "This is test content"

      html_result = %{content: content, format: :html, metadata: %{}}
      assert ResultHandler.extract_metadata(html_result).size_bytes > 0

      pdf_result = %{content: content, format: :pdf, metadata: %{}}
      assert ResultHandler.extract_metadata(pdf_result).size_bytes > 0

      json_result = %{content: content, format: :json, metadata: %{}}
      assert ResultHandler.extract_metadata(json_result).size_bytes > 0
    end
  end

  describe "format_for_display/2" do
    test "formats HTML for inline display" do
      result = %{
        content: "<html><body>Report</body></html>",
        format: :html
      }

      display = ResultHandler.format_for_display(result, :inline)

      assert display.type == :html
      assert display.content == result.content
      assert display.safe == false
    end

    test "formats PDF for download" do
      result = %{
        content: <<"%PDF-1.4">>,
        format: :pdf
      }

      display = ResultHandler.format_for_display(result, :download)

      assert display.type == :download
      assert display.mime_type == "application/pdf"
      assert is_binary(display.filename)
      assert String.ends_with?(display.filename, ".pdf")
      assert display.size > 0
    end

    test "formats JSON for inline display with pretty printing" do
      json_content = Jason.encode!(%{test: "data", nested: %{value: 123}})

      result = %{
        content: json_content,
        format: :json
      }

      display = ResultHandler.format_for_display(result, :inline)

      assert display.type == :code
      assert display.language == "json"
      assert is_binary(display.content)
    end

    test "formats HEEX for component rendering" do
      result = %{
        content: "<div>Test</div>",
        format: :heex
      }

      display = ResultHandler.format_for_display(result, :inline)

      assert display.type == :component
      assert display.content == result.content
    end

    test "handles unknown format/display combinations" do
      result = %{
        content: "unknown",
        format: :unknown_format
      }

      display = ResultHandler.format_for_display(result, :inline)

      assert display.type == :raw
    end
  end

  describe "get_execution_summary/1" do
    test "creates comprehensive execution summary" do
      result = %{
        content: "test",
        metadata: %{
          execution_time_ms: 2500,
          record_count: 500
        },
        format: :html
      }

      summary = ResultHandler.get_execution_summary(result)

      assert is_binary(summary.summary_text)
      assert summary.summary_text =~ "500 records"
      assert summary.summary_text =~ "2.5s"

      assert is_list(summary.details)
      assert length(summary.details) > 0

      assert is_map(summary.performance)
      assert summary.performance.execution_time_ms == 2500
      assert summary.performance.record_count == 500
      assert is_float(summary.performance.records_per_second)
    end

    test "calculates records per second correctly" do
      result = %{
        content: "test",
        metadata: %{
          execution_time_ms: 1000,  # 1 second
          record_count: 100
        },
        format: :html
      }

      summary = ResultHandler.get_execution_summary(result)

      assert summary.performance.records_per_second == 100.0
    end

    test "handles zero execution time" do
      result = %{
        content: "test",
        metadata: %{
          execution_time_ms: 0,
          record_count: 100
        },
        format: :html
      }

      summary = ResultHandler.get_execution_summary(result)

      assert summary.performance.records_per_second == 0
    end
  end

  describe "parse_error/1" do
    test "parses error with complete information" do
      error = %{
        stage: :data_loading,
        reason: :invalid_query,
        message: "Query failed"
      }

      parsed = ResultHandler.parse_error(error)

      assert parsed.stage == :data_loading
      assert parsed.reason == :invalid_query
      assert parsed.user_message == "Query failed"
      assert is_binary(parsed.suggested_action)
      assert is_binary(parsed.technical_details)
    end

    test "parses string error" do
      parsed = ResultHandler.parse_error("Simple error message")

      assert parsed.stage == :unknown
      assert parsed.user_message == "Simple error message"
      assert is_binary(parsed.suggested_action)
    end

    test "parses unexpected error types" do
      parsed = ResultHandler.parse_error({:unexpected, :error})

      assert parsed.stage == :unknown
      assert is_binary(parsed.user_message)
      assert is_binary(parsed.technical_details)
    end

    test "suggests appropriate action for data_loading errors" do
      error = %{
        stage: :data_loading,
        reason: :error,
        message: "Failed"
      }

      parsed = ResultHandler.parse_error(error)

      assert parsed.suggested_action =~ "parameters"
    end

    test "suggests appropriate action for context_building errors" do
      error = %{
        stage: :context_building,
        reason: :error,
        message: "Failed"
      }

      parsed = ResultHandler.parse_error(error)

      assert parsed.suggested_action =~ "configuration"
    end

    test "suggests appropriate action for rendering errors" do
      error = %{
        stage: :rendering,
        reason: :error,
        message: "Failed"
      }

      parsed = ResultHandler.parse_error(error)

      assert parsed.suggested_action =~ "format" or parsed.suggested_action =~ "template"
    end
  end

  describe "helper functions" do
    test "format_duration handles milliseconds" do
      result = %{content: "", metadata: %{execution_time_ms: 500}, format: :html}
      summary = ResultHandler.get_execution_summary(result)

      assert summary.summary_text =~ "500ms" or summary.summary_text =~ "0.5s"
    end

    test "format_duration handles seconds" do
      result = %{content: "", metadata: %{execution_time_ms: 5000}, format: :html}
      summary = ResultHandler.get_execution_summary(result)

      assert summary.summary_text =~ "5" and summary.summary_text =~ "s"
    end

    test "format_duration handles minutes" do
      result = %{content: "", metadata: %{execution_time_ms: 125000}, format: :html}
      summary = ResultHandler.get_execution_summary(result)

      # Should show as minutes and seconds
      assert summary.summary_text =~ "m"
    end

    test "format_bytes handles different sizes" do
      small_result = %{content: "x", metadata: %{}, format: :html}
      summary = ResultHandler.get_execution_summary(small_result)
      assert summary.details |> Enum.any?(&String.contains?(&1, "B"))

      medium_content = String.duplicate("x", 2000)
      medium_result = %{content: medium_content, metadata: %{}, format: :html}
      summary = ResultHandler.get_execution_summary(medium_result)
      assert summary.details |> Enum.any?(&String.contains?(&1, "KB"))
    end
  end
end
