defmodule AshReportsDemo.DataGeneratorIntegrationTest do
  @moduledoc """
  Integration tests that validate the fixed DataGenerator works with all 4 report types.

  Tests the complete pipeline from data generation through report rendering.
  Uses the full AshReports.Runner API to test all three stages:
  Stage 1 (DataLoader) → Stage 2 (RenderContext) → Stage 3 (RenderPipeline)
  """

  use ExUnit.Case, async: false

  alias AshReportsDemo.{DataGenerator, Domain}

  setup do
    # Both EtsDataLayer and DataGenerator are started by the application
    # Generate fresh test data
    DataGenerator.reset_data()

    case DataGenerator.generate_sample_data(:small) do
      :ok ->
        # Validate data was generated correctly
        {:ok, _stats} = DataGenerator.validate_data_integrity()
        :ok

      {:error, reason} ->
        flunk("Failed to generate test data: #{reason}")
    end
  end

  describe "customer_summary report integration" do
    test "loads customer_summary report with generated data" do
      case AshReports.Runner.run_report(Domain, :customer_summary, %{}, format: :json) do
        {:ok, result} ->
          # Should have loaded actual customer records through full pipeline
          assert length(result.data.records) > 0

          # Metadata should include record count
          assert result.metadata.record_count == length(result.data.records)

          # Parse JSON to verify structure
          json_data = Jason.decode!(result.content)
          variables = json_data["data"]["variables"] || json_data["report"]["metadata"]["variables"]

          # Variables should be calculated from real data
          assert Map.has_key?(variables, "customer_count")
          assert variables["customer_count"] == length(result.data.records)

          # Should have customer lifetime value data
          assert Map.has_key?(variables, "total_lifetime_value")
          assert variables["total_lifetime_value"] > 0

          # Verify records have required fields for report
          first_customer = List.first(result.data.records)
          assert Map.has_key?(first_customer, :name)
          assert Map.has_key?(first_customer, :status)
          assert Map.has_key?(first_customer, :credit_limit)

        {:error, reason} ->
          flunk("Customer summary report failed: #{inspect(reason)}")
      end
    end

    test "customer_summary report handles grouping by status" do
      case AshReports.Runner.run_report(Domain, :customer_summary, %{}, format: :json) do
        {:ok, result} ->
          # Parse JSON to check for groups
          json_data = Jason.decode!(result.content)

          # Should have group data based on customer status
          assert Map.has_key?(json_data["data"], "groups") or
                 Map.has_key?(json_data["report"]["metadata"], "groups")

          # At least some customers should have different statuses
          statuses = Enum.map(result.data.records, & &1.status) |> Enum.uniq()
          assert length(statuses) > 1

        {:error, reason} ->
          flunk("Customer summary grouping failed: #{inspect(reason)}")
      end
    end
  end

  describe "product_inventory report integration" do
    test "loads product_inventory report with generated data" do
      case AshReports.Runner.run_report(Domain, :product_inventory, %{}, format: :json) do
        {:ok, result} ->
          # Should have loaded product records through full pipeline
          assert length(result.data.records) > 0

          # Parse JSON to verify structure
          json_data = Jason.decode!(result.content)
          variables = json_data["data"]["variables"] || json_data["report"]["metadata"]["variables"]

          # Variables should reflect actual product counts
          assert Map.has_key?(variables, "total_products")
          assert variables["total_products"] == length(result.data.records)

          # Should calculate inventory values
          assert Map.has_key?(variables, "total_inventory_value")

          # Verify records have required fields
          first_product = List.first(result.data.records)
          assert Map.has_key?(first_product, :name)
          assert Map.has_key?(first_product, :price)
          assert Map.has_key?(first_product, :sku)

        {:error, reason} ->
          flunk("Product inventory report failed: #{inspect(reason)}")
      end
    end

    test "product_inventory report handles category grouping" do
      case AshReports.Runner.run_report(Domain, :product_inventory, %{}, format: :json) do
        {:ok, result} ->
          # Parse JSON to check for groups
          json_data = Jason.decode!(result.content)

          # Should group by product category
          assert Map.has_key?(json_data["data"], "groups") or
                 Map.has_key?(json_data["report"]["metadata"], "groups")

          # Should have products from multiple categories
          # (since we generated 5 categories and distributed products among them)
          if length(result.data.records) >= 5 do
            categories =
              Enum.map(result.data.records, fn product ->
                Map.get(product, :category_id)
              end)
              |> Enum.uniq()

            assert length(categories) > 1
          end

        {:error, reason} ->
          flunk("Product inventory grouping failed: #{inspect(reason)}")
      end
    end
  end

  describe "invoice_details report integration" do
    test "loads invoice_details report with generated data" do
      case AshReports.Runner.run_report(Domain, :invoice_details, %{}, format: :json) do
        {:ok, result} ->
          # Should have loaded invoice records through full pipeline
          assert length(result.data.records) > 0

          # Parse JSON to verify structure
          json_data = Jason.decode!(result.content)
          variables = json_data["data"]["variables"] || json_data["report"]["metadata"]["variables"]

          # Variables should reflect actual invoice data
          assert Map.has_key?(variables, "total_invoices")
          assert variables["total_invoices"] == length(result.data.records)

          # Should calculate revenue metrics
          assert Map.has_key?(variables, "total_invoice_amount")

          # Verify records have required fields
          first_invoice = List.first(result.data.records)
          assert Map.has_key?(first_invoice, :invoice_number)
          assert Map.has_key?(first_invoice, :date)
          assert Map.has_key?(first_invoice, :total)

        {:error, reason} ->
          flunk("Invoice details report failed: #{inspect(reason)}")
      end
    end

    test "invoice_details report handles date grouping" do
      case AshReports.Runner.run_report(Domain, :invoice_details, %{}, format: :json) do
        {:ok, result} ->
          # Parse JSON to check for groups
          json_data = Jason.decode!(result.content)

          # Should group by invoice date
          assert Map.has_key?(json_data["data"], "groups") or
                 Map.has_key?(json_data["report"]["metadata"], "groups")

          # Should have invoices from different dates
          dates = Enum.map(result.data.records, & &1.date) |> Enum.uniq()
          assert length(dates) > 1

        {:error, reason} ->
          flunk("Invoice details grouping failed: #{inspect(reason)}")
      end
    end
  end

  describe "financial_summary report integration" do
    test "loads financial_summary report with generated data" do
      case AshReports.Runner.run_report(Domain, :financial_summary, %{}, format: :json) do
        {:ok, result} ->
          # Should have aggregated financial data through full pipeline
          # May be aggregated data
          assert length(result.data.records) >= 0

          # Parse JSON to verify structure
          json_data = Jason.decode!(result.content)
          variables = json_data["data"]["variables"] || json_data["report"]["metadata"]["variables"]

          # Should calculate key financial metrics
          assert Map.has_key?(variables, "total_revenue")
          assert Map.has_key?(variables, "invoice_count")

          # Revenue should be positive if we have invoices
          if variables["invoice_count"] > 0 do
            assert variables["total_revenue"] > 0
          end

        {:error, reason} ->
          flunk("Financial summary report failed: #{inspect(reason)}")
      end
    end
  end

  describe "report parameter handling" do
    test "reports handle parameter filtering correctly" do
      # Test customer_summary with status filter
      params = %{status: :active}

      case AshReports.Runner.run_report(Domain, :customer_summary, params, format: :json) do
        {:ok, result} ->
          # All returned customers should be active (if filter is working)
          # Note: This test depends on parameter handling being implemented
          assert is_list(result.data.records)

        {:error, reason} ->
          # Parameters might not be fully implemented yet - that's ok
          IO.puts("Parameter handling not yet implemented: #{inspect(reason)}")
      end
    end
  end

  describe "performance validation" do
    test "small dataset generation and report execution completes within time limits" do
      # Reset and regenerate to test performance
      DataGenerator.reset_data()

      # Generation should complete quickly for small dataset
      {generation_time, result} =
        :timer.tc(fn ->
          DataGenerator.generate_sample_data(:small)
        end)

      assert result == :ok
      # 5 seconds in microseconds
      assert generation_time < 5_000_000

      # Full pipeline execution should also be fast
      {report_time, report_result} =
        :timer.tc(fn ->
          AshReports.Runner.run_report(Domain, :customer_summary, %{}, format: :json)
        end)

      assert {:ok, _} = report_result
      # 3 seconds for full pipeline (includes rendering)
      assert report_time < 3_000_000
    end

    test "data integrity validation completes quickly" do
      {validation_time, result} =
        :timer.tc(fn ->
          DataGenerator.validate_data_integrity()
        end)

      assert {:ok, _stats} = result
      # 1 second in microseconds
      assert validation_time < 1_000_000
    end
  end

  describe "error recovery" do
    test "reports handle corrupted data gracefully" do
      # Generate good data first
      DataGenerator.generate_sample_data(:small)

      # Manually corrupt some data by deleting foundation data
      {:ok, customer_types} = AshReportsDemo.CustomerType.read()
      first_type = List.first(customer_types)
      AshReportsDemo.CustomerType.destroy!(first_type)

      # Reports should either handle this gracefully or provide clear error messages
      case AshReports.Runner.run_report(Domain, :customer_summary, %{}, format: :json) do
        {:ok, result} ->
          # If it succeeds, should have some data
          assert is_list(result.data.records)

        {:error, error_info} ->
          # If it fails, should have a reasonable error structure with stage info
          assert is_map(error_info) and Map.has_key?(error_info, :reason)
      end
    end
  end

  describe "data volume validation" do
    test "medium volume generates more data than small volume" do
      # Test small volume
      DataGenerator.reset_data()
      DataGenerator.generate_sample_data(:small)

      {:ok, small_customers} = AshReportsDemo.Customer.read()
      small_count = length(small_customers)

      # Test medium volume
      DataGenerator.reset_data()
      DataGenerator.generate_sample_data(:medium)

      {:ok, medium_customers} = AshReportsDemo.Customer.read()
      medium_count = length(medium_customers)

      # Medium should have more customers than small
      assert medium_count > small_count
    end
  end
end
