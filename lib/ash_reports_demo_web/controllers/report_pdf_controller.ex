defmodule AshReportsDemoWeb.ReportPdfController do
  @moduledoc """
  Controller for PDF report downloads.

  Handles PDF generation and streaming with proper headers and error handling.
  """

  use AshReportsDemoWeb, :controller

  alias AshReportsDemoWeb.Reports.PipelineClient

  @doc """
  Download a report as PDF.

  Accepts report parameters via query string and generates a PDF for download.
  """
  def download(conn, %{"name" => report_name_str} = params) do
    with {:ok, report_name} <- parse_report_name(report_name_str),
         report_params <- parse_params(params),
         {:ok, result} <-
           PipelineClient.run_report(
             AshReportsDemo.Domain,
             report_name,
             report_params,
             format: :pdf
           ) do
      serve_pdf(conn, result, report_name)
    else
      {:error, :invalid_report_name} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: AshReportsDemoWeb.ErrorHTML)
        |> render(:"404")

      {:error, :report_not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: AshReportsDemoWeb.ErrorHTML)
        |> render(:"404")

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> put_view(html: AshReportsDemoWeb.ErrorHTML)
        |> render(:"500")
    end
  end

  defp parse_report_name(name_str) do
    {:ok, String.to_existing_atom(name_str)}
  rescue
    ArgumentError -> {:error, :invalid_report_name}
  end

  defp parse_params(params) do
    params
    |> Enum.filter(fn {key, _value} -> key not in ["name", "format"] end)
    |> Enum.into(%{}, fn {key, value} ->
      try do
        {String.to_existing_atom(key), value}
      rescue
        ArgumentError -> {key, value}
      end
    end)
  end

  defp serve_pdf(conn, result, report_name) do
    filename = generate_filename(report_name, result.metadata)

    conn
    |> put_resp_content_type("application/pdf")
    |> put_resp_header(
      "content-disposition",
      ~s(attachment; filename="#{filename}")
    )
    |> put_resp_header("content-length", to_string(byte_size(result.content)))
    |> send_resp(200, result.content)
  end

  defp generate_filename(report_name, metadata) do
    timestamp =
      DateTime.utc_now()
      |> DateTime.to_iso8601(:basic)
      |> String.replace(~r/[:.]/, "")
      |> String.slice(0, 15)

    report_title =
      metadata[:report_name] ||
        report_name
        |> to_string()
        |> String.replace("_", "-")

    "#{report_title}_#{timestamp}.pdf"
  end
end
