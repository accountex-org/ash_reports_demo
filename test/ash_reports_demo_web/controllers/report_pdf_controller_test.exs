defmodule AshReportsDemoWeb.ReportPdfControllerTest do
  use AshReportsDemoWeb.ConnCase, async: false

  setup do
    AshReportsDemo.DataGenerator.generate_sample_data(:small)
    :ok
  end

  describe "download/2" do
    @tag :pdf
    test "downloads PDF for valid report", %{conn: conn} do
      conn = get(conn, ~p"/reports/customer_summary/pdf")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/pdf"]
      assert [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ "attachment"
      assert disposition =~ "customer"
      assert disposition =~ ".pdf"
    end

    test "returns 404 for invalid report name", %{conn: conn} do
      conn = get(conn, ~p"/reports/nonexistent/pdf")

      assert conn.status == 404
    end

    @tag :pdf
    test "generates filename with timestamp", %{conn: conn} do
      conn = get(conn, ~p"/reports/financial_summary/pdf")

      assert conn.status == 200
      [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ ~r/financial.*\d{8,}/
    end

    @tag :pdf
    test "accepts report parameters in query string", %{conn: conn} do
      conn = get(conn, ~p"/reports/customer_summary/pdf?min_health_score=50")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/pdf"]
    end

    @tag :pdf
    test "includes content-length header", %{conn: conn} do
      conn = get(conn, ~p"/reports/customer_summary/pdf")

      assert conn.status == 200
      assert [length] = get_resp_header(conn, "content-length")
      assert String.to_integer(length) > 0
    end
  end
end
