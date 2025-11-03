defmodule AshReportsDemo.Charts do
  @moduledoc """
  Chart definitions for the AshReports Demo.

  NOTE: This module uses programmatic chart definitions rather than the Chart DSL
  because the domain-level Chart DSL is still under development in AshReports.

  In the future, these definitions will be migrated to the domain.ex file using
  the Chart DSL once it's fully supported.
  """

  alias AshReportsDemo.ChartData

  @doc """
  Returns all available chart definitions.
  """
  def charts do
    [
      # Migrated charts (from old implementation)
      customer_status_distribution(),
      monthly_revenue(),
      product_sales_by_category(),
      top_products_by_revenue(),

      # New demonstration charts
      inventory_levels_over_time(),
      price_quantity_analysis(),
      invoice_payment_timeline(),
      customer_health_trend()
    ]
  end

  @doc """
  Gets a chart by name.
  """
  def get_chart(name) when is_atom(name) do
    Enum.find(charts(), &(&1.name == name))
  end

  def get_chart(name) when is_binary(name) do
    name
    |> String.to_existing_atom()
    |> get_chart()
  rescue
    ArgumentError -> nil
  end

  # Chart Definitions

  defp customer_status_distribution do
    %{
      name: :customer_status_distribution,
      type: :pie_chart,
      title: "Customer Status Distribution",
      description: "Distribution of customers by status (Active, Inactive, Suspended)",
      data_fetcher: &ChartData.fetch_customer_status_data/0,
      config: %{
        width: 600,
        height: 400,
        colours: ["10B981", "F59E0B", "EF4444"],
        data_labels: true
      }
    }
  end

  defp monthly_revenue do
    %{
      name: :monthly_revenue,
      type: :line_chart,
      title: "Monthly Revenue Trend",
      description: "Total invoice revenue over time",
      data_fetcher: &ChartData.fetch_monthly_revenue_data/0,
      config: %{
        width: 800,
        height: 400,
        colours: ["3B82F6"],
        smoothed: true,
        stroke_width: "2",
        axis_label_rotation: :auto
      }
    }
  end

  defp product_sales_by_category do
    %{
      name: :product_sales_by_category,
      type: :bar_chart,
      title: "Sales by Product Category",
      description: "Number of line items sold per product category",
      data_fetcher: &ChartData.fetch_product_sales_data/0,
      config: %{
        width: 700,
        height: 450,
        colours: ["8B5CF6", "EC4899", "F59E0B", "10B981", "3B82F6"],
        type: :simple,
        orientation: :vertical,
        data_labels: true,
        padding: 2
      }
    }
  end

  defp top_products_by_revenue do
    %{
      name: :top_products_by_revenue,
      type: :bar_chart,
      title: "Top 10 Products by Revenue",
      description: "Top selling products ranked by total revenue generated",
      data_fetcher: &ChartData.fetch_top_products_data/0,
      config: %{
        width: 800,
        height: 500,
        colours: ["059669"],
        type: :simple,
        orientation: :horizontal,
        data_labels: true,
        padding: 2
      }
    }
  end

  defp inventory_levels_over_time do
    %{
      name: :inventory_levels_over_time,
      type: :area_chart,
      title: "Inventory Levels Trend",
      description: "Historical trend of inventory levels across all products",
      data_fetcher: &ChartData.fetch_inventory_levels_data/0,
      config: %{
        width: 800,
        height: 400,
        colours: ["10B981"],
        mode: :simple,
        opacity: 0.7,
        smooth_lines: true
      }
    }
  end

  defp price_quantity_analysis do
    %{
      name: :price_quantity_analysis,
      type: :scatter_chart,
      title: "Price vs Quantity Correlation",
      description: "Correlation between product price and sales quantity",
      data_fetcher: &ChartData.fetch_price_quantity_data/0,
      config: %{
        width: 700,
        height: 500,
        colours: ["8B5CF6"],
        axis_label_rotation: :auto
      }
    }
  end

  defp invoice_payment_timeline do
    %{
      name: :invoice_payment_timeline,
      type: :gantt_chart,
      title: "Invoice Payment Timeline",
      description: "Timeline visualization of invoice payment schedules",
      data_fetcher: &ChartData.fetch_payment_timeline_data/0,
      config: %{
        width: 900,
        height: 400,
        colours: ["3B82F6"],
        show_task_labels: true,
        padding: 2
      }
    }
  end

  defp customer_health_trend do
    %{
      name: :customer_health_trend,
      type: :sparkline,
      title: "Customer Health Trend",
      description: "Compact visualization of customer health score trends",
      data_fetcher: &ChartData.fetch_health_sparkline_data/0,
      config: %{
        width: 150,
        height: 30,
        spot_radius: 2,
        spot_colour: "red",
        line_width: 1,
        line_colour: "rgba(0, 200, 50, 0.7)",
        fill_colour: "rgba(0, 200, 50, 0.2)"
      }
    }
  end

  @doc """
  Generates a chart by name, fetching data and rendering to SVG.
  Returns `{:ok, %{svg: svg_string, data: data, chart: chart_def}}` or `{:error, reason}`.
  """
  def generate_chart(chart_name) when is_atom(chart_name) do
    case get_chart(chart_name) do
      nil ->
        {:error, "Chart not found: #{chart_name}"}

      chart ->
        with {:ok, data} <- chart.data_fetcher.(),
             {:ok, svg} <- render_chart(chart.type, data, chart.config) do
          {:ok, %{svg: svg, data: data, chart: chart}}
        end
    end
  end

  defp render_chart(chart_type, data, config) do
    # Convert config map to AshReports.Charts.Config struct
    config_struct = struct(AshReports.Charts.Config, format_config(config))

    # Generate chart using AshReports.Charts
    AshReports.Charts.generate(chart_type, data, config_struct, cache_ttl: 300_000)
  end

  defp format_config(config) do
    %{
      title: config[:title],
      width: config[:width] || 600,
      height: config[:height] || 400,
      colors: format_colors(config[:colours] || config[:colors]),
      show_legend: config[:show_legend] || false,
      show_grid: config[:show_grid] || false,
      show_data_labels: config[:data_labels] || false,
      x_axis_label: config[:x_axis_label],
      y_axis_label: config[:y_axis_label]
    }
  end

  defp format_colors(nil), do: nil

  defp format_colors(colors) when is_list(colors) do
    Enum.map(colors, fn color ->
      if String.starts_with?(color, "#"), do: color, else: "##{color}"
    end)
  end

  defp format_colors(colors), do: colors
end
