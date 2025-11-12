defmodule AshReportsDemo.SessionMetrics do
  @moduledoc """
  Ash resource for tracking session metrics over time.

  This resource stores aggregated session data by time periods (hour, day)
  to enable charting session trends and usage patterns.
  """

  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :timestamp, :utc_datetime_usec, allow_nil?: false
    attribute :period_type, :atom, allow_nil?: false, constraints: [one_of: [:hour, :day]]
    attribute :period_start, :utc_datetime_usec, allow_nil?: false

    # Metrics
    attribute :total_sessions, :integer, default: 0
    attribute :new_sessions, :integer, default: 0
    attribute :page_views, :integer, default: 0
    attribute :unique_sessions_active, :integer, default: 0

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  code_interface do
    define :create
    define :read
  end
end
