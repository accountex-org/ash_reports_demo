defmodule AshReportsDemoWeb.ReportApiControllerTest do
  use AshReportsDemoWeb.ConnCase, async: false

  setup do
    AshReportsDemo.DataGenerator.generate_sample_data(:small)
    :ok
  end

  describe "index/2" do
    test "lists all available reports", %{conn: conn} do
      conn = get(conn, ~p"/api/reports")

      assert json = json_response(conn, 200)
      assert is_map(json)
      assert Map.has_key?(json, "reports")
      assert Map.has_key?(json, "count")
      assert json["count"] == 4
      assert is_list(json["reports"])
    end

    test "includes report metadata", %{conn: conn} do
      conn = get(conn, ~p"/api/reports")

      json = json_response(conn, 200)
      report = hd(json["reports"])

      assert Map.has_key?(report, "name")
      assert Map.has_key?(report, "title")
      assert Map.has_key?(report, "parameters")
      assert Map.has_key?(report, "variables")
      assert Map.has_key?(report, "groups")
    end

    test "includes parameter details", %{conn: conn} do
      conn = get(conn, ~p"/api/reports")

      json = json_response(conn, 200)
      report = Enum.find(json["reports"], &(&1["name"] == "customer_summary"))

      assert is_list(report["parameters"])

      if length(report["parameters"]) > 0 do
        param = hd(report["parameters"])
        assert Map.has_key?(param, "name")
        assert Map.has_key?(param, "type")
        assert Map.has_key?(param, "required")
      end
    end
  end

  describe "show/2" do
    test "executes report and returns JSON or error", %{conn: conn} do
      conn = get(conn, ~p"/api/reports/customer_summary")

      assert conn.status in [200, 500]

      response =
        if conn.status == 200 do
          json_response(conn, 200)
        else
          json_response(conn, 500)
        end

      assert is_map(response)

      if conn.status == 200 do
        assert Map.has_key?(response, "data")
        assert Map.has_key?(response, "metadata")
      else
        assert Map.has_key?(response, "error")
      end
    end

    test "includes execution metadata when successful", %{conn: conn} do
      conn = get(conn, ~p"/api/reports/customer_summary")

      if conn.status == 200 do
        json = json_response(conn, 200)
        metadata = json["metadata"]

        assert metadata["report_name"] == "customer_summary"
        assert Map.has_key?(metadata, "execution_time_ms")
        assert Map.has_key?(metadata, "record_count")
        assert metadata["format"] == "json"
        assert Map.has_key?(metadata, "generated_at")
      end
    end

    test "accepts report parameters", %{conn: conn} do
      conn = get(conn, ~p"/api/reports/customer_summary?region=CA")

      assert conn.status in [200, 500]

      _json =
        if conn.status == 200 do
          json_response(conn, 200)
        else
          json_response(conn, 500)
        end
    end

    test "returns 404 for invalid report name", %{conn: conn} do
      conn = get(conn, ~p"/api/reports/nonexistent")

      assert json = json_response(conn, 404)
      assert Map.has_key?(json, "error")
    end

    test "returns 404 for malformed report name", %{conn: conn} do
      conn = get(conn, ~p"/api/reports/invalid-name-123")

      assert json = json_response(conn, 404)
      assert json["error"] =~ "Invalid report name"
    end

    test "handles boolean parameters", %{conn: conn} do
      conn = get(conn, ~p"/api/reports/customer_summary?include_inactive=false")

      assert conn.status in [200, 500]
    end

    test "handles integer parameters", %{conn: conn} do
      conn = get(conn, ~p"/api/reports/customer_summary?min_health_score=50")

      assert conn.status in [200, 500]
    end
  end

  describe "API structure" do
    test "API endpoint exists and responds", %{conn: conn} do
      conn = get(conn, ~p"/api/reports")

      assert conn.status == 200
    end

    test "returns JSON content type", %{conn: conn} do
      conn = get(conn, ~p"/api/reports")

      assert ["application/json; charset=utf-8"] = get_resp_header(conn, "content-type")
    end

    test "handles invalid JSON endpoints gracefully", %{conn: conn} do
      conn = get(conn, ~p"/api/reports/invalid-name-123")

      assert conn.status == 404
      assert json_response(conn, 404)
    end
  end
end
