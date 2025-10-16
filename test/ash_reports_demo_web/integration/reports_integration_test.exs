defmodule AshReportsDemoWeb.ReportsIntegrationTest do
  use AshReportsDemoWeb.ConnCase

  import PhoenixTest

  setup do
    AshReportsDemo.DataGenerator.generate_sample_data(:small)
    :ok
  end

  describe "Reports page navigation" do
    test "user can navigate to reports index", %{conn: conn} do
      conn
      |> visit("/")
      |> click_link("Reports")
      |> assert_has("h1", text: "Available Reports")
    end

    test "reports index displays available reports", %{conn: conn} do
      conn
      |> visit("/reports")
      |> assert_has("h1", text: "Available Reports")
      |> assert_has("text", text: "Customer Summary Report")
      |> assert_has("text", text: "Product Inventory Report")
      |> assert_has("text", text: "Invoice Details Report")
      |> assert_has("text", text: "Executive Financial Summary")
    end

    test "user can access customer summary report", %{conn: conn} do
      conn
      |> visit("/reports")
      |> click_link("Configure & Run", at: 0)
      |> assert_has("h1", text: "Customer Summary Report")
    end
  end

  describe "Report viewer functionality" do
    test "report viewer displays format selector", %{conn: conn} do
      conn
      |> visit("/reports/customer_summary")
      |> assert_has("select[name=format]")
      |> assert_has("option", text: "HTML")
      |> assert_has("option", text: "JSON")
      |> assert_has("option", text: "HEEX")
      |> assert_has("option", text: "PDF")
    end

    test "report viewer displays parameters section", %{conn: conn} do
      conn
      |> visit("/reports/customer_summary")
      |> assert_has("h3", text: "Parameters")
      |> assert_has("button", text: "Run Report")
    end

    test "user can run a report", %{conn: conn} do
      conn
      |> visit("/reports/customer_summary")
      |> click_button("Run Report")
      |> assert_has("text", text: "Report Results")
    end

    test "user can navigate back from report viewer", %{conn: conn} do
      conn
      |> visit("/reports/customer_summary")
      |> click_link("Back to Reports")
      |> assert_has("h1", text: "Available Reports")
    end
  end

  describe "Data generation functionality" do
    test "user can regenerate sample data from reports index", %{conn: conn} do
      conn
      |> visit("/reports")
      |> click_button("Regenerate Data")
      |> assert_has("text", text: "Sample data regenerated successfully!")
    end
  end

  describe "Search functionality" do
    test "user can search for reports", %{conn: conn} do
      conn
      |> visit("/reports")
      |> fill_in("Search reports...", with: "customer")
      |> assert_has("text", text: "Customer Summary Report")
    end
  end

  describe "Quick run functionality" do
    test "user can quick run report with HTML format", %{conn: conn} do
      conn
      |> visit("/reports")
      |> click_button("HTML", at: 0)
      |> assert_has("h1", text: "Customer Summary Report")
    end
  end

  describe "Navigation flow" do
    test "complete user journey through reports", %{conn: conn} do
      # Start from home page
      conn
      |> visit("/")

      # Navigate to reports
      |> click_link("Reports")
      |> assert_has("h1", text: "Available Reports")

      # Generate sample data
      |> click_button("Regenerate Data")
      |> assert_has("text", text: "Sample data regenerated successfully!")

      # View customer summary report
      |> click_link("Configure & Run", at: 0)
      |> assert_has("h1", text: "Customer Summary Report")

      # Run the report
      |> click_button("Run Report")
      |> assert_has("text", text: "Report Results")

      # Navigate back
      |> click_link("Back to Reports")
      |> assert_has("h1", text: "Available Reports")
    end
  end
end
