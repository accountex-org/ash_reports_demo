defmodule AshReportsDemoWeb.PdfController do
  use AshReportsDemoWeb, :controller

  alias AshReportsDemoWeb.PdfStore

  def download(conn, %{"id" => pdf_id}) do
    case PdfStore.get_pdf(pdf_id) do
      {:ok, pdf_entry} ->
        filename = Map.get(pdf_entry.metadata, :filename, "report.pdf")

        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, pdf_entry.content)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: AshReportsDemoWeb.ErrorHTML)
        |> render(:"404")

      {:error, :expired} ->
        conn
        |> put_status(:gone)
        |> put_view(html: AshReportsDemoWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def view(conn, %{"id" => pdf_id}) do
    case PdfStore.get_pdf(pdf_id) do
      {:ok, pdf_entry} ->
        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", "inline")
        |> send_resp(200, pdf_entry.content)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: AshReportsDemoWeb.ErrorHTML)
        |> render(:"404")

      {:error, :expired} ->
        conn
        |> put_status(:gone)
        |> put_view(html: AshReportsDemoWeb.ErrorHTML)
        |> render(:"404")
    end
  end
end
