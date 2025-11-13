defmodule AshReportsDemo.SessionSnapshot do
  @moduledoc """
  Ash resource for individual session records.

  This resource tracks individual sessions to enable detailed session analysis
  and supports querying for bounce rates, session duration, etc.
  """

  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :session_id, :string, allow_nil?: false, public?: true
    attribute :first_seen, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :last_seen, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :page_views, :integer, default: 1, public?: true
    attribute :user_agent, :string, public?: true
    attribute :is_bounce, :boolean, default: false, public?: true

    timestamps()
  end

  calculations do
    calculate :session_duration_minutes,
              :integer,
              expr(
                fragment(
                  "CASE WHEN ? > ? THEN CAST(EXTRACT(EPOCH FROM (? - ?)) / 60 AS INTEGER) ELSE 0 END",
                  last_seen,
                  first_seen,
                  last_seen,
                  first_seen
                )
              )

    calculate :created_date, :date, expr(fragment("DATE(?)", created_at))

    calculate :created_hour,
              :utc_datetime_usec,
              expr(fragment("DATE_TRUNC('hour', ?)", created_at))
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      accept [:session_id, :first_seen, :last_seen, :page_views, :user_agent, :is_bounce]
    end

    read :by_date_range do
      argument :start_date, :date, allow_nil?: false
      argument :end_date, :date, allow_nil?: false

      filter expr(created_at >= ^arg(:start_date) and created_at <= ^arg(:end_date))
    end
  end

  code_interface do
    define :create
    define :read
    define :by_date_range, args: [:start_date, :end_date]
  end
end
