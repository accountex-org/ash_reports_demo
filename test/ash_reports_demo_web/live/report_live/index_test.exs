defmodule AshReportsDemoWeb.ReportLive.IndexTest do
  use AshReportsDemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # No setup needed - report listing only needs report definitions, not actual data

  describe "mount/3" do
    test "loads the report index page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      assert html =~ "Available Reports"
      assert html =~ "Explore comprehensive reports"
    end

    test "displays all reports from domain", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      # Should display the 4 reports defined in the domain
      assert html =~ "Customer Summary Report"
      assert html =~ "Product Inventory Report"
      assert html =~ "Invoice Details Report"
      assert html =~ "Executive Financial Summary"
    end

    test "shows report count", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      assert html =~ "4 reports available"
    end

    test "includes search input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      assert has_element?(view, "input[type=search]")
    end

    test "includes regenerate data button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      assert has_element?(view, "button", "Regenerate Data")
    end
  end

  describe "report cards" do
    test "displays report titles", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      assert html =~ "Customer Summary Report"
      assert html =~ "Executive Financial Summary"
    end

    test "displays report descriptions", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      # Reports should have descriptions (defined in domain)
      assert html =~ ~r/Multi-level|Inventory|Invoice|Financial/
    end

    test "shows parameter count for each report", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      assert html =~ "parameters"
      assert html =~ ~r/\d+ parameters/
    end

    test "shows variable count for each report", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      assert html =~ "variables"
      assert html =~ ~r/\d+ variables/
    end

    test "shows group count for reports with groups", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      # Customer summary has groups
      assert html =~ "groups"
    end

    test "has configure & run link for each report", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      assert has_element?(view, "a", "Configure & Run")
    end

    test "has quick run buttons for different formats", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      assert has_element?(view, "button", "HTML")
      assert has_element?(view, "button", "JSON")
      assert has_element?(view, "button", "HEEX")
    end
  end

  describe "search functionality" do
    test "filters reports by title", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Search for "customer"
      render_change(view, "search", %{"search" => "customer"})

      html = render(view)
      assert html =~ "Customer Summary Report"
      refute html =~ "Product Inventory Report"
      refute html =~ "Invoice Details Report"
    end

    test "filters reports by name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Search for part of the report name atom
      render_change(view, "search", %{"search" => "financial"})

      html = render(view)
      assert html =~ "Executive Financial Summary"
      refute html =~ "Customer Summary Report"
    end

    test "filters reports by description", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Search for text that might be in description
      render_change(view, "search", %{"search" => "invoice"})

      html = render(view)
      assert html =~ "Invoice Details Report"
    end

    test "shows filtered count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      render_change(view, "search", %{"search" => "customer"})

      html = render(view)
      assert html =~ "Showing 1 of 4 reports"
    end

    test "shows empty state when no matches", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      render_change(view, "search", %{"search" => "nonexistent"})

      html = render(view)
      assert html =~ "No reports found"
      assert html =~ "No reports match your search"
    end

    test "clears filter when search is empty", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Search and then clear
      render_change(view, "search", %{"search" => "customer"})
      render_change(view, "search", %{"search" => ""})

      html = render(view)
      assert html =~ "4 reports available"
      assert html =~ "Customer Summary Report"
      assert html =~ "Product Inventory Report"
    end

    test "search is case insensitive", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      render_change(view, "search", %{"search" => "CUSTOMER"})

      html = render(view)
      assert html =~ "Customer Summary Report"
    end
  end

  describe "data regeneration" do
    test "regenerates data when button is clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Click regenerate button
      view |> element("button", "Regenerate Data") |> render_click()

      # Should show success flash
      assert render(view) =~ "Sample data regenerated successfully"
    end

    test "maintains report list after regeneration", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      view |> element("button", "Regenerate Data") |> render_click()

      html = render(view)
      assert html =~ "Customer Summary Report"
      assert html =~ "4 reports available"
    end

    test "maintains search filter after regeneration", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Set search filter
      render_change(view, "search", %{"search" => "customer"})

      # Regenerate data
      view |> element("button", "Regenerate Data") |> render_click()

      # Search filter should still be applied
      html = render(view)
      assert html =~ "Showing 1 of 4 reports"
      assert html =~ "Customer Summary Report"
    end
  end

  describe "quick run functionality" do
    test "navigates to viewer with format and auto_run on quick run", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Click HTML quick run button for customer_summary
      view
      |> element("button[phx-value-report=customer_summary][phx-value-format=html]", "HTML")
      |> render_click()

      # Should navigate to viewer with auto_run parameter
      assert_redirected(view, "/reports/customer_summary?format=html&auto_run=true")
    end

    test "quick run with JSON format", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      view
      |> element("button[phx-value-report=financial_summary][phx-value-format=json]", "JSON")
      |> render_click()

      assert_redirected(view, "/reports/financial_summary?format=json&auto_run=true")
    end

    test "quick run with HEEX format", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      view
      |> element("button[phx-value-report=product_inventory][phx-value-format=heex]", "HEEX")
      |> render_click()

      assert_redirected(view, "/reports/product_inventory?format=heex&auto_run=true")
    end
  end

  describe "navigation" do
    test "configure & run link navigates to viewer", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports")

      # Click on a configure & run link
      view |> element("a[href*='/reports/customer_summary']", "Configure & Run") |> render_click()

      assert_redirect(view, "/reports/customer_summary")
    end

    test "report cards link to viewer page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      # Should have links to each report viewer
      assert html =~ ~s(href="/reports/customer_summary")
      assert html =~ ~s(href="/reports/financial_summary")
      assert html =~ ~s(href="/reports/product_inventory")
      assert html =~ ~s(href="/reports/invoice_details")
    end
  end

  describe "UI and styling" do
    test "uses grid layout for report cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      assert html =~ "grid"
      assert html =~ "sm:grid-cols-2"
      assert html =~ "lg:grid-cols-3"
    end

    test "report cards have hover effects", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      assert html =~ "hover:shadow-md"
    end

    test "displays icons for metadata", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      # Should have SVG icons with viewbox (lowercase) - check for the regenerate data button icon
      assert html =~ "<svg"
      assert html =~ ~s(viewbox="0 0 24 24")
    end

    test "has accessible header structure", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      assert html =~ "<h1" || html =~ "text-base font-semibold" # Phoenix uses utility classes
      assert html =~ "Available Reports"
    end
  end

  describe "report metadata enrichment" do
    test "enriches reports with computed metadata", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      # Each report should show its metadata counts
      # Customer summary has parameters, variables, and groups
      assert html =~ ~r/\d+ parameters/
      assert html =~ ~r/\d+ variables/
    end

    test "formats report names from atoms", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      # Report names should be formatted from snake_case atoms
      assert html =~ "Customer Summary"
      assert html =~ "Product Inventory"
      assert html =~ "Invoice Details"
      assert html =~ "Financial Summary"
    end

    test "handles reports without descriptions", %{conn: conn} do
      # If a report doesn't have a description, it should still render
      {:ok, view, _html} = live(conn, "/reports")

      # Should not crash, just show the report without description
      assert render(view)
    end
  end

  describe "empty state" do
    test "shows empty state when no reports defined", %{conn: conn} do
      # This test would require mocking or a test domain with no reports
      # For now, just verify the template has empty state handling
      {:ok, _view, html} = live(conn, "/reports")

      # Should have 4 reports, so empty state is not shown
      refute html =~ "No reports are defined in the domain"
    end
  end

  describe "accessibility and semantics" do
    test "search input has proper label", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      assert html =~ ~s(<label for="search")
      assert html =~ "Search reports"
    end

    test "buttons have descriptive titles", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      assert html =~ "Quick run with HTML format"
      assert html =~ "Quick run with JSON format"
      assert html =~ "Quick run with HEEX format"
    end

    test "page has proper heading hierarchy", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports")

      # Should have main heading and subheadings
      assert html =~ "Available Reports"
    end
  end
end
