defmodule AshReportsDemoWeb.Integration.PipelineIntegrationTest do
  use AshReportsDemoWeb.ConnCase, async: false

  alias AshReportsDemoWeb.Reports.PipelineClient

  setup do
    AshReportsDemo.DataGenerator.generate_sample_data(:small)
    :ok
  end

  describe "end-to-end report execution" do
    test "executes customer_summary report through pipeline" do
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{},
        format: :html
      )

      assert result.format == :html
      assert result.metadata.record_count >= 0
      assert is_binary(result.content)
    end

    test "executes product_inventory report through pipeline" do
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :product_inventory,
        %{},
        format: :html
      )

      assert result.format == :html
      assert result.metadata.record_count >= 0
      assert is_binary(result.content)
    end

    test "executes invoice_details report through pipeline" do
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :invoice_details,
        %{},
        format: :html
      )

      assert result.format == :html
      assert result.metadata.record_count >= 0
      assert is_binary(result.content)
    end

    test "executes financial_summary report through pipeline" do
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :financial_summary,
        %{},
        format: :html
      )

      assert result.format == :html
      assert result.metadata.record_count >= 0
      assert is_binary(result.content)
    end
  end

  describe "output formats" do
    test "generates HTML output" do
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{},
        format: :html
      )

      assert result.format == :html
      assert is_binary(result.content)
      assert String.contains?(result.content, "<") || String.length(result.content) > 0
    end

    test "generates JSON output" do
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{},
        format: :json
      )

      assert result.format == :json
      assert is_binary(result.content)
    end

    test "generates HEEX output" do
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{},
        format: :heex
      )

      assert result.format == :heex
      assert is_binary(result.content)
    end

    @tag :pdf
    test "generates PDF output" do
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{},
        format: :pdf
      )

      assert result.format == :pdf
      assert is_binary(result.content)
    end
  end

  describe "error scenarios" do
    test "handles invalid report name" do
      assert {:error, :report_not_found} =
               PipelineClient.run_report(
                 AshReportsDemo.Domain,
                 :nonexistent_report,
                 %{},
                 format: :html
               )
    end

    test "handles invalid format" do
      assert {:error, reason} =
               PipelineClient.run_report(
                 AshReportsDemo.Domain,
                 :customer_summary,
                 %{},
                 format: :invalid_format
               )

      # Error is returned as a string message, not just the atom
      assert is_binary(reason)
      assert reason =~ "invalid_format"
    end

    test "validates parameters successfully for valid input" do
      result =
        PipelineClient.validate_parameters(
          AshReportsDemo.Domain,
          :customer_summary,
          %{}
        )

      assert result == :ok || match?({:ok, _}, result)
    end
  end

  describe "pipeline metadata" do
    test "includes execution metadata" do
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{},
        format: :html
      )

      assert is_map(result.metadata)
      assert Map.has_key?(result.metadata, :execution_time_ms)
      assert Map.has_key?(result.metadata, :record_count)
      # Format is not included in metadata, it's in result.format
    end

    test "tracks pipeline stages" do
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{},
        format: :html
      )

      assert is_list(result.metadata.stages_executed)
    end
  end

  describe "parameter handling" do
    test "accepts valid parameters for customer_summary" do
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{min_health_score: 50},
        format: :html
      )

      assert result.format == :html
      assert is_binary(result.content)
    end

    test "handles optional parameters" do
      {:ok, result} = PipelineClient.run_report(
        AshReportsDemo.Domain,
        :customer_summary,
        %{include_inactive: true},
        format: :html
      )

      assert result.format == :html
    end
  end

  describe "performance" do
    test "completes small reports within reasonable time" do
      {time_us, {:ok, _result}} =
        :timer.tc(fn ->
          PipelineClient.run_report(
            AshReportsDemo.Domain,
            :customer_summary,
            %{},
            format: :html
          )
        end)

      time_ms = time_us / 1000
      assert time_ms < 10_000, "Expected < 10s, got #{time_ms}ms"
    end
  end
end
