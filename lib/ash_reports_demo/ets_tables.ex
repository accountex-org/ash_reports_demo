defmodule AshReportsDemo.EtsTables do
  @moduledoc """
  Utility functions for managing ETS tables used by Ash resources.

  These tables are automatically created by Ash.DataLayer.Ets when resources are loaded.
  This module provides helper functions to clear and inspect them.
  """

  @table_names [
    :demo_customers,
    :demo_customer_addresses,
    :demo_customer_types,
    :demo_products,
    :demo_product_categories,
    :demo_inventory,
    :demo_invoices,
    :demo_invoice_line_items,
    :telemetry_events,
    :telemetry_metrics
  ]

  @doc """
  List of all ETS table names used by the application.
  """
  def table_names, do: @table_names

  @doc """
  Ensure all ETS tables exist.
  Creates any missing tables with the same configuration Ash.DataLayer.Ets would use.
  """
  @spec ensure_tables_exist() :: :ok
  def ensure_tables_exist do
    Enum.each(@table_names, fn table_name ->
      case :ets.whereis(table_name) do
        :undefined ->
          # Create table with same options as Ash.DataLayer.Ets
          :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])

        _ref ->
          :ok
      end
    end)

    :ok
  end

  @doc """
  Clear all data from ETS tables.
  """
  @spec clear_all_data() :: :ok
  def clear_all_data do
    Enum.each(@table_names, fn table_name ->
      case :ets.whereis(table_name) do
        :undefined ->
          # Table doesn't exist yet, skip it
          :ok

        _ref ->
          :ets.delete_all_objects(table_name)
      end
    end)

    :ok
  end

  @doc """
  Get table statistics for all tables.

  Returns a map with:
  - :tables - map of table_name => %{size: count, memory_words: words}
  - :total_records - total number of records across all tables
  - :total_memory_words - total memory usage in words
  """
  @spec table_stats() :: map()
  def table_stats do
    stats =
      @table_names
      |> Enum.map(fn table_name ->
        case :ets.whereis(table_name) do
          :undefined ->
            {table_name, %{size: 0, memory_words: 0}}

          _ref ->
            size = :ets.info(table_name, :size) || 0
            memory = :ets.info(table_name, :memory) || 0
            {table_name, %{size: size, memory_words: memory}}
        end
      end)
      |> Map.new()

    total_size = stats |> Map.values() |> Enum.map(& &1.size) |> Enum.sum()
    total_memory = stats |> Map.values() |> Enum.map(& &1.memory_words) |> Enum.sum()

    %{
      tables: stats,
      total_records: total_size,
      total_memory_words: total_memory
    }
  end

  @doc """
  Extract all data from specified ETS table.

  Returns a list of all records in the table.
  """
  @spec extract_table_data(atom()) :: list()
  def extract_table_data(table_name) do
    case :ets.whereis(table_name) do
      :undefined -> []
      _ref -> :ets.tab2list(table_name)
    end
  end
end
