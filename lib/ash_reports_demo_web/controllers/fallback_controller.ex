defmodule AshReportsDemoWeb.FallbackController do
  @moduledoc """
  Fallback controller for API error handling.
  """

  use AshReportsDemoWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: AshReportsDemoWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: AshReportsDemoWeb.ErrorJSON)
    |> render(:"401")
  end

  def call(conn, {:error, reason}) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: "Internal server error", details: inspect(reason)})
  end
end
