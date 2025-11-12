defmodule AshReportsDemo.Resources.TelemetryEvent do
  @moduledoc """
  Tracks telemetry events for charts and reports.
  
  Stores detailed information about each operation including timing,
  data points processed, and metadata.
  """

  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: AshReportsDemo.EtsDataLayer

  resource do
    description "Telemetry events for chart and report operations"
  end

  ets do
    table :telemetry_events
  end

  attributes do
    uuid_primary_key :id

    attribute :event_type, :atom do
      description "Type of operation (chart_data_query, chart_generate, report_data_query, report_generate)"
      allow_nil? false
    end

    attribute :operation_name, :string do
      description "Name of the chart or report being processed"
      allow_nil? false
    end

    attribute :operation_type, :string do
      description "Type of chart (pie_chart, bar_chart, etc.) or report format"
    end

    attribute :duration_microseconds, :integer do
      description "Duration of the operation in microseconds"
      allow_nil? false
    end

    attribute :data_points, :integer do
      description "Number of data points processed"
      default 0
    end

    attribute :success, :boolean do
      description "Whether the operation completed successfully"
      allow_nil? false
      default true
    end

    attribute :error_message, :string do
      description "Error message if the operation failed"
    end

    attribute :metadata, :map do
      description "Additional metadata about the operation"
      default %{}
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :event_type,
        :operation_name,
        :operation_type,
        :duration_microseconds,
        :data_points,
        :success,
        :error_message,
        :metadata
      ]
    end
  end

  preparations do
    prepare build(sort: [inserted_at: :desc])
  end

  code_interface do
    domain AshReportsDemo.Domain

    define :create, args: [:event_type, :operation_name, :duration_microseconds]
    define :read
    define :list, action: :read
  end
end