defmodule AshReportsDemo.SessionTracker do
  @moduledoc """
  GenServer to track unique sessions and usage statistics for the demo application.

  Maintains an ETS table to store session information including:
  - Session ID
  - First seen timestamp
  - Last seen timestamp
  - Page views count
  - User agent (optional)
  """

  use GenServer
  require Logger

  @table_name :session_tracker
  @cleanup_interval :timer.hours(1)
  @session_timeout :timer.hours(24)

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records a session visit.
  """
  def track_session(session_id, user_agent \\ nil) do
    GenServer.call(__MODULE__, {:track_session, session_id, user_agent})
  end

  @doc """
  Gets total number of unique sessions.
  """
  def get_total_sessions do
    GenServer.call(__MODULE__, :get_total_sessions)
  end

  @doc """
  Gets detailed session statistics.
  """
  def get_session_stats do
    GenServer.call(__MODULE__, :get_session_stats)
  end

  @doc """
  Gets active sessions (within last 24 hours).
  """
  def get_active_sessions do
    GenServer.call(__MODULE__, :get_active_sessions)
  end

  @doc """
  Gets all session data (for debugging).
  """
  def get_all_sessions do
    GenServer.call(__MODULE__, :get_all_sessions)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for storing session data
    table = :ets.new(@table_name, [:set, :protected, :named_table])

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("SessionTracker started with table: #{inspect(table)}")
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:track_session, session_id, user_agent}, _from, state) do
    now = System.system_time(:second)

    case :ets.lookup(@table_name, session_id) do
      [] ->
        # New session
        session_data = %{
          session_id: session_id,
          first_seen: now,
          last_seen: now,
          page_views: 1,
          user_agent: user_agent
        }

        :ets.insert(@table_name, {session_id, session_data})
        Logger.debug("New session tracked: #{session_id}")

      [{^session_id, existing_data}] ->
        # Update existing session
        updated_data = %{
          existing_data
          | last_seen: now,
            page_views: existing_data.page_views + 1
        }

        :ets.insert(@table_name, {session_id, updated_data})
        Logger.debug("Session updated: #{session_id}, views: #{updated_data.page_views}")
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_total_sessions, _from, state) do
    count = :ets.info(@table_name, :size)
    {:reply, count, state}
  end

  @impl true
  def handle_call(:get_session_stats, _from, state) do
    sessions = :ets.tab2list(@table_name)
    now = System.system_time(:second)

    stats = %{
      total_sessions: length(sessions),
      active_sessions: count_active_sessions(sessions, now),
      total_page_views: calculate_total_page_views(sessions),
      average_page_views: calculate_average_page_views(sessions),
      oldest_session: find_oldest_session(sessions),
      newest_session: find_newest_session(sessions)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:get_active_sessions, _from, state) do
    sessions = :ets.tab2list(@table_name)
    now = System.system_time(:second)
    active_count = count_active_sessions(sessions, now)
    {:reply, active_count, state}
  end

  @impl true
  def handle_call(:get_all_sessions, _from, state) do
    sessions = :ets.tab2list(@table_name)
    session_data = Enum.map(sessions, fn {_id, data} -> data end)
    {:reply, session_data, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_sessions()
    schedule_cleanup()
    {:noreply, state}
  end

  ## Private Functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_old_sessions do
    now = System.system_time(:second)
    cutoff = now - div(@session_timeout, 1000)

    # Find and delete old sessions
    old_sessions =
      :ets.select(@table_name, [
        {{:"$1", %{last_seen: :"$2"}}, [{:<, :"$2", cutoff}], [:"$1"]}
      ])

    Enum.each(old_sessions, fn session_id ->
      :ets.delete(@table_name, session_id)
    end)

    if length(old_sessions) > 0 do
      Logger.info("Cleaned up #{length(old_sessions)} old sessions")
    end
  end

  defp count_active_sessions(sessions, now) do
    cutoff = now - div(@session_timeout, 1000)

    sessions
    |> Enum.count(fn {_id, %{last_seen: last_seen}} ->
      last_seen > cutoff
    end)
  end

  defp calculate_total_page_views(sessions) do
    sessions
    |> Enum.reduce(0, fn {_id, %{page_views: views}}, acc ->
      acc + views
    end)
  end

  defp calculate_average_page_views(sessions) when length(sessions) == 0, do: 0

  defp calculate_average_page_views(sessions) do
    total_views = calculate_total_page_views(sessions)
    Float.round(total_views / length(sessions), 2)
  end

  defp find_oldest_session([]), do: nil

  defp find_oldest_session(sessions) do
    {_id, oldest_data} =
      Enum.min_by(sessions, fn {_id, %{first_seen: first_seen}} ->
        first_seen
      end)

    DateTime.from_unix!(oldest_data.first_seen)
  end

  defp find_newest_session([]), do: nil

  defp find_newest_session(sessions) do
    {_id, newest_data} =
      Enum.max_by(sessions, fn {_id, %{first_seen: first_seen}} ->
        first_seen
      end)

    DateTime.from_unix!(newest_data.first_seen)
  end
end
