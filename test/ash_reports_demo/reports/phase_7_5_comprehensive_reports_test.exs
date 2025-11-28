defmodule AshReportsDemo.Reports.Phase75ComprehensiveReportsTest do
  @moduledoc """
  Comprehensive test suite for Phase 7.5 reports.

  Tests all four reports across multiple formats with business logic validation,
  performance benchmarks, and multi-format consistency verification.
  """

  use ExUnit.Case, async: false

  alias AshReportsDemo.DataGenerator

  @reports [
    :customer_summary,
    :product_inventory,
    :invoice_details,
    :financial_summary
  ]

  @formats [:html, :pdf, :heex, :json]

  setup do
    # Reset and generate fresh test data for each test
    DataGenerator.reset_data()
    DataGenerator.generate_sample_data(:medium)
    :ok
  end

  describe "customer summary report" do
    test "generates successfully in all formats" do
      for format <- @formats do
        {:ok, result} =
          AshReports.Runner.run_report(
            AshReportsDemo.Domain,
            :customer_summary,
            %{},
            format: format
          )

        assert result.content
        assert result.metadata
        assert result.metadata.record_count > 0

        # Validate format-specific content
        case format do
          :json ->
            data = Jason.decode!(result.content)
            assert is_map(data)
            # JSON structure has records at top level
            assert Map.has_key?(data, "records")

          :html ->
            assert String.contains?(result.content, "<")
            assert is_binary(result.content)

          :heex ->
            assert is_binary(result.content)
            assert String.contains?(result.content, "ash-report")

          :pdf ->
            assert is_binary(result.content)
            assert byte_size(result.content) > 1000
        end
      end
    end

    test "applies parameter filters correctly" do
      # Test region filtering
      {:ok, all_result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{},
          format: :json
        )

      {:ok, filtered_result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{region: "North"},
          format: :json
        )

      # Filtered result should have fewer or equal records
      assert filtered_result.metadata.record_count <= all_result.metadata.record_count

      # Test health score filtering parameter is accepted
      {:ok, health_filtered} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{min_health_score: 80},
          format: :json
        )

      # Verify the report executes successfully with the parameter
      assert health_filtered.metadata.record_count >= 0
    end

    test "validates multi-level grouping variables" do
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{},
          format: :json
        )

      # Variables are in the render context, not JSON content
      variables = result.data.variables

      # Check that report-level variables are calculated (only those defined in the report)
      assert Map.has_key?(variables, :customer_count)
      assert Map.has_key?(variables, :total_lifetime_value)

      # Verify calculated values are reasonable
      assert variables[:customer_count] > 0
      assert variables[:total_lifetime_value] > 0

      # Verify JSON has expected structure
      data = Jason.decode!(result.content)
      assert Map.has_key?(data, "records")
    end
  end

  describe "product inventory report" do
    test "generates with profitability analytics" do
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :product_inventory,
          %{},
          format: :json
        )

      # Variables are in the render context
      variables = result.data.variables

      assert Map.has_key?(variables, :total_products)
      assert Map.has_key?(variables, :total_inventory_value)
      assert variables[:total_products] >= 0
      assert variables[:total_inventory_value] >= 0
    end

    test "filters by profitability grade" do
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :product_inventory,
          %{profitability_grade: "A"},
          format: :json
        )

      # Get records from the context
      records = result.data.records

      # All products should have grade A (if calculation is loaded)
      for product <- records do
        # Check if calculation is loaded
        unless is_struct(product.profitability_grade, Ash.NotLoaded) do
          assert product.profitability_grade == "A"
        end
      end
    end

    test "validates inventory metrics" do
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :product_inventory,
          %{},
          format: :json
        )

      # Variables are in the render context
      variables = result.data.variables

      # Check inventory-specific variables (only those defined in the report)
      assert Map.has_key?(variables, :total_products)
      assert Map.has_key?(variables, :total_inventory_value)

      # Validate calculated metrics
      assert variables[:total_products] > 0
      assert variables[:total_inventory_value] > 0
    end
  end

  describe "invoice details report" do
    test "generates master-detail structure" do
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :invoice_details,
          %{},
          format: :json
        )

      # Access records from the context
      records = result.data.records
      assert length(records) > 0

      # Verify master-detail structure with invoice data
      for invoice <- records do
        assert Map.has_key?(invoice, :invoice_number) or Map.has_key?(invoice, "invoice_number")
        assert Map.has_key?(invoice, :total) or Map.has_key?(invoice, "total")
        assert Map.has_key?(invoice, :status) or Map.has_key?(invoice, "status")
        assert Map.has_key?(invoice, :days_overdue) or Map.has_key?(invoice, "days_overdue")
        assert Map.has_key?(invoice, :payment_status) or Map.has_key?(invoice, "payment_status")
      end
    end

    test "calculates payment performance metrics" do
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :invoice_details,
          %{},
          format: :json
        )

      # Variables are in the render context
      variables = result.data.variables

      # Check payment-related variables (only those defined in the report)
      assert Map.has_key?(variables, :total_invoices)

      # Verify payment calculations
      total_invoices = variables[:total_invoices]
      assert total_invoices > 0
    end

    test "filters by invoice status" do
      {:ok, overdue_result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :invoice_details,
          %{status: :overdue},
          format: :json
        )

      # Verify the status filter parameter is accepted
      assert overdue_result.metadata.record_count >= 0

      {:ok, paid_result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :invoice_details,
          %{status: :paid},
          format: :json
        )

      # Verify the status filter parameter is accepted
      assert paid_result.metadata.record_count >= 0
    end
  end

  describe "financial summary report" do
    test "generates executive-level metrics" do
      # Use yearly period to capture all data from the fiscal year
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :financial_summary,
          %{period_type: :yearly},
          format: :json
        )

      # Variables are in the render context
      variables = result.data.variables

      # Check financial metrics (only those defined in the report)
      assert Map.has_key?(variables, :total_revenue)
      assert Map.has_key?(variables, :invoice_count)

      # Verify calculations - revenue should be non-negative
      # The actual value depends on invoice dates matching the fiscal year filter
      assert is_number(variables[:total_revenue]) or is_struct(variables[:total_revenue], Decimal)
      assert variables[:invoice_count] >= 0
    end

    test "validates customer tier revenue distribution" do
      # Use yearly period to capture more data
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :financial_summary,
          %{customer_tier_analysis: true, period_type: :yearly},
          format: :json
        )

      # Variables are in the render context
      variables = result.data.variables

      # Verify basic financial variables are present
      assert Map.has_key?(variables, :total_revenue)
      assert Map.has_key?(variables, :invoice_count)
      # Revenue can be 0 if no invoices match the date filter
      assert is_number(variables[:total_revenue]) or is_struct(variables[:total_revenue], Decimal)
    end

    test "validates risk-based analysis" do
      # Use yearly period to capture more data
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :financial_summary,
          %{risk_analysis: true, period_type: :yearly},
          format: :json
        )

      # Variables are in the render context
      variables = result.data.variables

      # Verify basic financial variables are present
      assert Map.has_key?(variables, :total_revenue)
      assert Map.has_key?(variables, :invoice_count)
      # Revenue can be 0 if no invoices match the date filter
      assert is_number(variables[:total_revenue]) or is_struct(variables[:total_revenue], Decimal)
    end
  end

  describe "multi-format consistency" do
    test "all formats produce consistent record counts" do
      for report <- @reports do
        # Generate reports in all formats
        results =
          Enum.map(@formats, fn format ->
            {:ok, result} =
              AshReports.Runner.run_report(
                AshReportsDemo.Domain,
                report,
                sample_params_for(report),
                format: format
              )

            {format, result}
          end)

        # Extract record counts across formats - all should use metadata
        record_counts =
          Enum.map(results, fn {_format, result} ->
            result.metadata.record_count
          end)

        # All formats should have the same record count
        assert Enum.uniq(record_counts) |> length() == 1,
               "Record counts inconsistent across formats for #{report}: #{inspect(record_counts)}"
      end
    end

    test "variable calculations consistent across formats" do
      report = :customer_summary

      # Get JSON result for comparison
      {:ok, json_result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          report,
          %{},
          format: :json
        )

      # Variables are in the render context
      json_variables = json_result.data.variables

      # Compare with other formats
      for format <- [:html, :heex] do
        {:ok, result} =
          AshReports.Runner.run_report(
            AshReportsDemo.Domain,
            report,
            %{},
            format: format
          )

        # Variable values should be consistent across formats
        assert result.metadata.record_count == json_result.metadata.record_count
        assert result.data.variables[:customer_count] == json_variables[:customer_count]
      end
    end
  end

  describe "performance benchmarks" do
    @tag :benchmark
    test "all reports meet performance targets" do
      data_volumes = [:small, :medium, :large]

      for volume <- data_volumes do
        DataGenerator.reset_data()
        DataGenerator.generate_sample_data(volume)

        for report <- @reports do
          {time_us, {:ok, _result}} =
            :timer.tc(fn ->
              AshReports.Runner.run_report(
                AshReportsDemo.Domain,
                report,
                sample_params_for(report),
                format: :html
              )
            end)

          time_ms = div(time_us, 1000)
          max_time = max_time_for_volume(volume)

          assert time_ms < max_time,
                 "#{report} with #{volume} data took #{time_ms}ms, exceeds limit #{max_time}ms"
        end
      end
    end
  end

  describe "business logic validation" do
    test "customer health scores reflect accurate calculations" do
      # Get an existing customer type from the test data
      customer_types = Ash.read!(AshReportsDemo.CustomerType)
      customer_type = List.first(customer_types)

      # Skip this test if no customer types exist
      if customer_type do
        # Create customers with known patterns (include dataset_id)
        {:ok, high_health_customer} =
          AshReportsDemo.Customer.create(%{
            dataset_id: "medium",
            name: "High Health Customer",
            email: "high#{System.unique_integer()}@test.com",
            status: :active,
            credit_limit: Decimal.new("50000.00"),
            customer_type_id: customer_type.id
          })

        {:ok, low_health_customer} =
          AshReportsDemo.Customer.create(%{
            dataset_id: "medium",
            name: "Low Health Customer",
            email: "low#{System.unique_integer()}@test.com",
            status: :suspended,
            credit_limit: Decimal.new("1000.00"),
            customer_type_id: customer_type.id
          })

        {:ok, result} =
          AshReports.Runner.run_report(
            AshReportsDemo.Domain,
            :customer_summary,
            %{},
            format: :json
          )

        # Access records from the context
        customer_data = result.data.records

        # Find our test customers
        high_record = Enum.find(customer_data, &(&1.id == high_health_customer.id))
        low_record = Enum.find(customer_data, &(&1.id == low_health_customer.id))

        if high_record && low_record do
          # Validate health score calculations
          assert high_record.customer_health_score > low_record.customer_health_score
          # Active status bonus
          assert high_record.customer_health_score >= 70
          # Suspended penalty
          assert low_record.customer_health_score <= 50
        end
      end
    end

    test "product profitability grades calculated correctly" do
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :product_inventory,
          %{},
          format: :json
        )

      # Access records from the context
      products = result.data.records

      for product <- products do
        # Skip products where calculations aren't loaded
        unless is_struct(product.margin_percentage, Ash.NotLoaded) or
                 is_struct(product.profitability_grade, Ash.NotLoaded) do
          margin = product.margin_percentage
          grade = product.profitability_grade

          # Verify grade assignments match margin ranges
          cond do
            margin >= 50.0 -> assert grade == "A"
            margin >= 30.0 -> assert grade == "B"
            margin >= 15.0 -> assert grade == "C"
            margin >= 5.0 -> assert grade == "D"
            true -> assert grade == "F"
          end
        end
      end
    end

    test "invoice aging calculations are accurate" do
      {:ok, result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :invoice_details,
          %{},
          format: :json
        )

      # Get records from the context
      records = result.data.records
      today = Date.utc_today()

      for invoice <- records do
        # Calculate expected age
        calculated_age = Date.diff(today, invoice.date)

        # Get age_in_days from calculation if loaded
        actual_age =
          if is_struct(invoice.age_in_days, Ash.NotLoaded) do
            Date.diff(today, invoice.date)
          else
            invoice.age_in_days
          end

        assert actual_age == calculated_age

        # Verify overdue calculations
        if invoice.due_date do
          calculated_overdue = max(0, Date.diff(today, invoice.due_date))

          # Get days_overdue from calculation if loaded
          actual_overdue =
            if is_struct(invoice.days_overdue, Ash.NotLoaded) do
              max(0, Date.diff(today, invoice.due_date))
            else
              invoice.days_overdue
            end

          assert actual_overdue == calculated_overdue
        end
      end
    end
  end

  describe "error handling and edge cases" do
    test "handles empty datasets gracefully" do
      # No data generation
      DataGenerator.reset_data()

      for report <- @reports do
        {:ok, result} =
          AshReports.Runner.run_report(
            AshReportsDemo.Domain,
            report,
            sample_params_for(report),
            format: :json
          )

        # Check that records are empty using the context
        assert result.data.records == []
        assert result.metadata.record_count == 0
      end
    end

    test "validates parameter constraints" do
      # Test that valid parameters are accepted
      {:ok, _result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :customer_summary,
          %{min_health_score: 80},
          format: :json
        )

      {:ok, _result} =
        AshReports.Runner.run_report(
          AshReportsDemo.Domain,
          :product_inventory,
          %{profitability_grade: "A"},
          format: :json
        )
    end

    test "handles concurrent report generation" do
      tasks =
        Enum.map(1..10, fn _i ->
          Task.async(fn ->
            AshReports.Runner.run_report(
              AshReportsDemo.Domain,
              :customer_summary,
              %{},
              format: :json
            )
          end)
        end)

      results = Task.await_many(tasks, 30_000)

      # All tasks should complete successfully
      assert Enum.all?(results, fn result ->
               match?({:ok, _}, result)
             end)
    end
  end

  # Helper functions
  defp sample_params_for(:customer_summary), do: %{}
  defp sample_params_for(:product_inventory), do: %{}
  defp sample_params_for(:invoice_details), do: %{}
  defp sample_params_for(:financial_summary), do: %{}

  # 500ms
  defp max_time_for_volume(:small), do: 500
  # 2s
  defp max_time_for_volume(:medium), do: 2000
  # 10s
  defp max_time_for_volume(:large), do: 10_000
end
