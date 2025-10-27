defmodule AshReportsDemoWeb.ReportApiController do
  @moduledoc """
  REST API controller for programmatic report execution.

  Provides JSON endpoints for listing and executing reports.
  """

  use AshReportsDemoWeb, :controller

  alias AshReportsDemoWeb.Reports.PipelineClient

  action_fallback AshReportsDemoWeb.FallbackController

  @doc """
  List all available reports with their metadata.
  """
  def index(conn, _params) do
    reports = AshReports.Info.reports(AshReportsDemo.Domain)

    enriched_reports =
      Enum.map(reports, fn report ->
        %{
          name: report.name,
          title: report.title || format_report_name(report.name),
          description: Map.get(report, :description),
          parameters: Enum.map(report.parameters, &format_parameter/1),
          variables: length(report.variables),
          groups: length(report.groups)
        }
      end)

    json(conn, %{
      reports: enriched_reports,
      count: length(enriched_reports)
    })
  end

  @doc """
  Execute a report and return JSON data.
  """
  def show(conn, %{"name" => report_name_str} = params) do
    with {:ok, report_name} <- parse_report_name(report_name_str),
         report_params <- parse_params(params),
         {:ok, result} <-
           PipelineClient.run_report(
             AshReportsDemo.Domain,
             report_name,
             report_params,
             format: :json
           ) do
      page = parse_integer(params["page"], 1)
      per_page = parse_integer(params["per_page"], 100)

      response = build_response(result, report_name, page, per_page)

      conn
      |> put_status(200)
      |> json(response)
    else
      {:error, :invalid_report_name} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Invalid report name"})

      {:error, :report_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Report not found"})

      {:error, :invalid_format} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid format"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Report execution failed", details: inspect(reason)})
    end
  end

  defp parse_report_name(name_str) do
    try do
      {:ok, String.to_existing_atom(name_str)}
    rescue
      ArgumentError -> {:error, :invalid_report_name}
    end
  end

  defp parse_params(params) do
    params
    |> Enum.filter(fn {key, _value} ->
      key not in ["name", "format", "page", "per_page"]
    end)
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      try do
        atom_key = String.to_existing_atom(key)
        Map.put(acc, atom_key, parse_param_value(value))
      rescue
        ArgumentError -> acc
      end
    end)
  end

  defp parse_param_value("true"), do: true
  defp parse_param_value("false"), do: false

  defp parse_param_value(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  defp parse_param_value(value), do: value

  defp parse_integer(nil, default), do: default

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_integer(value, _default) when is_integer(value) and value > 0, do: value
  defp parse_integer(_, default), do: default

  defp build_response(result, report_name, page, per_page) do
    data = parse_json_content(result.content)

    response = %{
      data: data,
      metadata: %{
        report_name: report_name,
        execution_time_ms: result.metadata.execution_time_ms,
        record_count: result.metadata.record_count,
        format: "json",
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    if is_map(data) && Map.has_key?(data, "records") do
      paginated = paginate_records(data["records"], page, per_page)

      Map.put(response, :pagination, paginated.pagination)
      |> Map.put(:data, Map.put(data, "records", paginated.records))
    else
      response
    end
  end

  defp parse_json_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, parsed} -> parsed
      {:error, _} -> %{raw: content}
    end
  end

  defp parse_json_content(content), do: content

  defp paginate_records(records, page, per_page) when is_list(records) do
    total = length(records)
    total_pages = ceil(total / per_page)
    start_index = (page - 1) * per_page
    paginated_records = Enum.slice(records, start_index, per_page)

    %{
      records: paginated_records,
      pagination: %{
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages
      }
    }
  end

  defp paginate_records(records, _page, _per_page), do: %{records: records, pagination: nil}

  defp format_report_name(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_parameter(param) do
    %{
      name: param.name,
      type: param.type,
      required: !Map.has_key?(param, :default),
      default: Map.get(param, :default),
      description: Map.get(param, :description)
    }
  end
end
