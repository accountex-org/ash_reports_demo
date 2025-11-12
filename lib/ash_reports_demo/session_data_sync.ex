defmodule AshReportsDemo.SessionDataSync do
  @moduledoc """
  Syncs session data from SessionTracker ETS to Ash resources for charting.
  """

  require Ash.Query
  alias AshReportsDemo.{SessionSnapshot, SessionMetrics}

  @doc """
  Syncs current session data to Ash resources for charting.
  This should be called periodically to keep chart data up-to-date.
  """
  def sync_session_data do
    try do
      # Get all current session data
      sessions = AshReportsDemo.SessionTracker.get_all_sessions()

      # Sync individual session snapshots
      sync_session_snapshots(sessions)

      # Generate hourly metrics
      generate_hourly_metrics(sessions)

      # Generate daily metrics  
      generate_daily_metrics(sessions)

      :ok
    rescue
      error ->
        require Logger
        Logger.error("Failed to sync session data: #{inspect(error)}")
        {:error, error}
    end
  end

  defp sync_session_snapshots(sessions) do
    # Clear existing snapshots to avoid duplicates
    SessionSnapshot |> Ash.read!() |> Enum.each(&Ash.destroy!/1)

    Enum.each(sessions, fn session_data ->
      first_seen = DateTime.from_unix!(session_data.first_seen)
      last_seen = DateTime.from_unix!(session_data.last_seen)
      is_bounce = session_data.page_views == 1

      SessionSnapshot.create!(%{
        session_id: session_data.session_id,
        first_seen: first_seen,
        last_seen: last_seen,
        page_views: session_data.page_views,
        user_agent: session_data.user_agent,
        is_bounce: is_bounce
      })
    end)
  end

  defp generate_hourly_metrics(sessions) do
    # Clear existing hourly metrics
    SessionMetrics
    |> Ash.Query.filter(period_type: :hour)
    |> Ash.read!()
    |> Enum.each(&Ash.destroy!/1)

    # Group sessions by hour
    sessions_by_hour =
      Enum.group_by(sessions, fn session ->
        DateTime.from_unix!(session.first_seen)
        |> DateTime.truncate(:second)
        |> Map.put(:minute, 0)
        |> Map.put(:second, 0)
        |> Map.put(:microsecond, {0, 0})
      end)

    Enum.each(sessions_by_hour, fn {hour_start, hour_sessions} ->
      total_sessions = length(hour_sessions)
      total_page_views = Enum.reduce(hour_sessions, 0, fn s, acc -> acc + s.page_views end)
      # For demo, all sessions are "new" in our current tracking
      new_sessions = total_sessions

      # Count unique active sessions (for simplicity, same as total for hourly)
      unique_sessions_active = total_sessions

      SessionMetrics.create!(%{
        timestamp: DateTime.utc_now(),
        period_type: :hour,
        period_start: hour_start,
        total_sessions: total_sessions,
        new_sessions: new_sessions,
        page_views: total_page_views,
        unique_sessions_active: unique_sessions_active
      })
    end)
  end

  defp generate_daily_metrics(sessions) do
    # Clear existing daily metrics
    SessionMetrics
    |> Ash.Query.filter(period_type: :day)
    |> Ash.read!()
    |> Enum.each(&Ash.destroy!/1)

    # Group sessions by day
    sessions_by_day =
      Enum.group_by(sessions, fn session ->
        DateTime.from_unix!(session.first_seen)
        |> DateTime.to_date()
      end)

    Enum.each(sessions_by_day, fn {date, day_sessions} ->
      total_sessions = length(day_sessions)
      total_page_views = Enum.reduce(day_sessions, 0, fn s, acc -> acc + s.page_views end)
      new_sessions = total_sessions
      unique_sessions_active = total_sessions

      # Convert date to datetime for period_start
      period_start = DateTime.new!(date, ~T[00:00:00.000000], "Etc/UTC")

      SessionMetrics.create!(%{
        timestamp: DateTime.utc_now(),
        period_type: :day,
        period_start: period_start,
        total_sessions: total_sessions,
        new_sessions: new_sessions,
        page_views: total_page_views,
        unique_sessions_active: unique_sessions_active
      })
    end)
  end
end
