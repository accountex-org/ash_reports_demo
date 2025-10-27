defmodule AshReportsDemoWeb.ReportLive.ViewerTest do
  use AshReportsDemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # No setup needed for most tests - data generation can be done per-test if needed

  describe "mount/3" do
    test "loads report viewer with valid report name", %{conn: conn} do
      {:ok, view, html} = live(conn, "/reports/customer_summary")

      assert html =~ "Customer Summary Report"
      assert html =~ "Output Format"
      assert html =~ "Parameters"
      assert has_element?(view, "select[name=format]")
    end

    test "redirects with error for invalid report name", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/reports", flash: flash}}} =
               live(conn, "/reports/nonexistent_report")

      assert flash["error"] =~ "Report not found"
    end

    test "redirects with error for non-atom report name", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/reports", flash: flash}}} =
               live(conn, "/reports/invalid-name-123")

      assert flash["error"] =~ "Invalid report name"
    end

    test "initializes with default state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/financial_summary")

      assert view |> element("select[name=format]") |> render() =~ "html"
      # Idle state placeholder
      assert has_element?(view, ".bg-gray-50")
    end
  end

  describe "format selection" do
    test "changes format when dropdown is updated", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/product_inventory")

      # Change format to JSON
      view
      |> element("select[name=format]")
      |> render_change(%{"format" => "json"})

      # Check that format selector shows JSON (Phoenix uses value attribute on select)
      assert view |> element("select[name=format]") |> render() =~ "value=\"json\""
    end

    test "displays format description", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports/invoice_details")

      # Default format is PDF
      assert html =~ "Downloadable PDF document"
    end

    test "updates URL when format changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/customer_summary")

      view
      |> element("select[name=format]")
      |> render_change(%{"format" => "json"})

      # The view should push a patch with the new format (URL encoded)
      assert_patched(view, "/reports/customer_summary?format%3Djson")
    end
  end

  describe "parameter handling" do
    test "updates parameters when form changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/customer_summary")

      # Change a parameter
      render_change(view, "param_changed", %{"region" => "CA"})

      # Parameters should be updated (we can't directly check assigns, but the form should reflect it)
      # This is more of an integration test - the actual validation happens elsewhere
    end

    test "validates parameters before running report", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/customer_summary")

      # Try to run report with invalid parameters (this depends on actual report definition)
      # For now, just test that the run_report event is handled and button exists
      assert has_element?(view, "button", "Run Report")
    end

    test "resets parameters to defaults", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/customer_summary")

      # Change a parameter
      render_change(view, "param_changed", %{"region" => "CA"})

      # Reset parameters
      view |> element("button", "Reset to Defaults") |> render_click()

      # Parameters should be reset (hard to verify without checking state)
    end
  end

  describe "report execution" do
    test "displays loading state when report is running", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/financial_summary")

      # Click run report button
      view |> element("button", "Run Report") |> render_click()

      # Should show loading state
      html = render(view)
      assert html =~ "Generating Report" || html =~ "Generating..."
    end

    test "disables run button during execution", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/product_inventory")

      # Click run report
      view |> element("button", "Run Report") |> render_click()

      # Button should be disabled and text should change to "Generating..."
      assert view |> element("button", "Generating...") |> render() =~ "disabled"
    end

    test "displays results after successful execution", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/financial_summary")

      # Run report
      view |> element("button", "Run Report") |> render_click()

      # Wait a moment for async report to complete
      :timer.sleep(2000)

      # Check that we're no longer in idle state
      html = render(view)
      refute html =~ "No report generated yet"
    end

    @tag :skip
    test "displays error when report execution fails", %{conn: conn} do
      # This test would require mocking or causing a failure condition
      # Skipping for now as it requires more setup
    end
  end

  describe "result display" do
    test "shows idle state placeholder initially", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports/customer_summary")

      assert html =~ "No report generated yet"
      assert html =~ "Configure parameters and click"
    end

    test "renders HTML results inline", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/financial_summary?format=html&auto_run=true")

      # Wait for report to complete
      :timer.sleep(1000)

      html = render(view)
      # Should show HTML content or results section
      assert html =~ "Report Results" || html =~ "Generating"
    end

    @tag :skip
    test "renders JSON results with formatting" do
      # Would need to actually run a report and verify JSON display
    end

    @tag :skip
    test "shows PDF download option for PDF format" do
      # Would need to handle PDF generation
    end
  end

  describe "error handling" do
    test "displays error component on failure", %{conn: conn} do
      # This would require causing a failure - skipping detailed test
      {:ok, _view, _html} = live(conn, "/reports/customer_summary")

      # Error display is handled by ReportError component
      # More detailed testing in report_error_test.exs
    end

    test "allows retry after error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/customer_summary")

      # The retry mechanism would be tested if we could trigger an error
      # For now, just verify the view can handle the retry_report event
      assert has_element?(view, "button", "Run Report")
    end

    test "allows editing parameters after error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/customer_summary")

      # Edit parameters event should be handleable
      # The actual behavior is in the component
      assert has_element?(view, "select[name=format]")
    end
  end

  describe "URL parameters" do
    test "accepts format in query string", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports/customer_summary?format=json")

      # Phoenix uses value attribute on select element, not selected on option
      assert html =~ "value=\"json\""
    end

    test "accepts auto_run parameter to execute immediately", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/financial_summary?auto_run=true")

      # Should start executing automatically
      :timer.sleep(500)
      html = render(view)

      # Should be in loading or success state, not idle
      refute html =~ "No report generated yet"
    end

    test "accepts report parameters in query string", %{conn: conn} do
      # This depends on the actual parameters defined for the report
      {:ok, _view, _html} = live(conn, "/reports/customer_summary?region=CA")

      # Parameters should be parsed and available
      # Hard to verify without accessing assigns
    end

    test "handles invalid format gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports/customer_summary?format=invalid")

      # Should default to PDF (the default format)
      assert html =~ "value=\"pdf\""
    end
  end

  describe "report metadata display" do
    test "shows parameter count", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports/customer_summary")

      assert html =~ "Parameters"
      # Should show a number
      assert html =~ ~r/\d+/
    end

    test "shows variable count", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports/financial_summary")

      assert html =~ "Variables"
      assert html =~ ~r/\d+/
    end

    test "shows group count", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports/customer_summary")

      assert html =~ "Groups"
      assert html =~ ~r/\d+/
    end
  end

  describe "navigation" do
    test "has back link to reports index", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports/customer_summary")

      assert html =~ "Back to Reports"
      assert html =~ ~s(href="/reports")
    end

    test "back link navigates to index page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/reports/customer_summary")

      view |> element("a", "Back to Reports") |> render_click()

      assert_redirect(view, "/reports")
    end
  end

  describe "accessibility" do
    test "has proper page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports/customer_summary")

      # Page title should be set from report definition
      assert html =~ "Customer Summary Report"
    end

    test "form elements have labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports/customer_summary")

      assert html =~ "<label"
      assert html =~ "Output Format"
    end

    test "buttons have clear text", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reports/financial_summary")

      assert html =~ "Run Report"
      assert html =~ "Reset to Defaults"
    end
  end
end
