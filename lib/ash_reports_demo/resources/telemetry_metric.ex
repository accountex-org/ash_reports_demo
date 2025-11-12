defmodule AshReportsDemo.Resources.TelemetryMetric do
  @moduledoc """
  Aggregated telemetry metrics for performance monitoring.
  
  Stores calculated metrics like averages, totals, and percentiles
  for different types of operations.
  """

  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: AshReportsDemo.EtsDataLayer

  resource do
    description "Aggregated telemetry metrics"
  end

  ets do
    table :telemetry_metrics
  end

  attributes do
    uuid_primary_key :id

    attribute :metric_type, :atom do
      description "Type of metric (avg_duration, total_operations, success_rate, etc.)"
      allow_nil? false
    end

    attribute :operation_category, :string do
      description "Category of operations (chart_data_query, chart_generate, etc.)"
      allow_nil? false
    end

    attribute :operation_name, :string do
      description "Specific operation name (optional, for per-operation metrics)"
    end

    attribute :metric_value, :float do
      description "The calculated metric value"
      allow_nil? false
    end

    attribute :sample_count, :integer do
      description "Number of samples used to calculate this metric"
      allow_nil? false
      default 0
    end

    attribute :time_window_start, :utc_datetime do
      description "Start of the time window for this metric"
    end

    attribute :time_window_end, :utc_datetime do
      description "End of the time window for this metric"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :metric_type,
        :operation_category,
        :operation_name,
        :metric_value,
        :sample_count,
        :time_window_start,
        :time_window_end
      ]
    end

    update :update do
      accept [
        :metric_value,
        :sample_count,
        :time_window_start,
        :time_window_end
      ]
    end
  end

  preparations do
    prepare build(sort: [updated_at: :desc])
  end

  code_interface do
    domain AshReportsDemo.Domain

    define :create, args: [:metric_type, :operation_category, :metric_value, :sample_count]
    define :read
    define :list, action: :read
    define :update
  end
end