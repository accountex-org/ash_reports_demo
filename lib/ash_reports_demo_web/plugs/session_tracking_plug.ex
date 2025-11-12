defmodule AshReportsDemoWeb.SessionTrackingPlug do
  @moduledoc """
  Plug to automatically track user sessions for analytics.

  This plug creates a unique session ID for each user and tracks their usage
  of the demo application. The session ID is stored in the session and
  persists across requests.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    {conn, session_id} = get_or_create_session_id(conn)
    user_agent = get_req_header(conn, "user-agent") |> List.first()

    # Track the session
    AshReportsDemo.SessionTracker.track_session(session_id, user_agent)

    # Store session_id in assigns for potential use in LiveViews
    assign(conn, :session_id, session_id)
  end

  defp get_or_create_session_id(conn) do
    case get_session(conn, :session_id) do
      nil ->
        # Generate a new session ID
        session_id = generate_session_id()
        updated_conn = put_session(conn, :session_id, session_id)
        Logger.debug("Generated new session ID: #{session_id}")
        {updated_conn, session_id}

      existing_session_id ->
        {conn, existing_session_id}
    end
  end

  defp generate_session_id do
    # Generate a unique session ID using timestamp + random data
    timestamp = System.system_time(:microsecond)
    random_part = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    "#{timestamp}-#{random_part}"
  end
end
