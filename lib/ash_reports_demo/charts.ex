defmodule AshReportsDemo.Charts do
  @moduledoc """
  Chart definitions for the demo application using AshReports.Charts.
  """

  alias AshReportsDemo.{Customer, Invoice, Product, InvoiceLineItem}
  alias AshReports.Charts.Config

  @doc """
  Returns all defined charts with their configurations.
  """
  def charts do
    [
      customer_status_chart(),
      monthly_revenue_chart(),
      product_sales_chart(),
      top_products_chart()
    ]
  end

  @doc """
  Gets a chart definition by name.
  """
  def get_chart(name) when is_atom(name) do
    Enum.find(charts(), &(&1.name == name))
  end

  def get_chart(name) when is_binary(name) do
    atom_name = String.to_existing_atom(name)
    get_chart(atom_name)
  rescue
    ArgumentError -> nil
  end

  @doc """
  Generates a chart using AshReports.Charts.
  Returns {:ok, svg_string} or {:error, reason}.
  """
  def generate_chart(chart_name) when is_atom(chart_name) do
    case get_chart(chart_name) do
      nil ->
        {:error, "Chart not found: #{chart_name}"}

      chart ->
        with {:ok, data} <- fetch_chart_data(chart),
             {:ok, svg} <- AshReports.Charts.generate(chart.type, data, chart.config, cache_ttl: 300_000) do
          {:ok, %{svg: svg, data: data, chart: chart}}
        end
    end
  end

  defp customer_status_chart do
    %{
      name: :customer_status_distribution,
      title: "Customer Status Distribution",
      description: "Distribution of customers by status (Active, Inactive, Suspended)",
      type: :pie,
      config: %Config{
        title: "Customer Status Distribution",
        width: 600,
        height: 400,
        colors: ["#10B981", "#F59E0B", "#EF4444"],
        show_legend: true,
        legend_position: :right,
        show_data_labels: true
      },
      data_fetcher: &fetch_customer_status_data/0
    }
  end

  defp monthly_revenue_chart do
    %{
      name: :monthly_revenue,
      title: "Monthly Revenue Trend",
      description: "Total invoice revenue over time",
      type: :line,
      config: %Config{
        title: "Monthly Revenue Trend",
        width: 800,
        height: 400,
        colors: ["#3B82F6"],
        show_legend: false,
        show_grid: true,
        x_axis_label: "Month",
        y_axis_label: "Revenue ($)",
        show_data_labels: false
      },
      data_fetcher: &fetch_monthly_revenue_data/0
    }
  end

  defp product_sales_chart do
    %{
      name: :product_sales_by_category,
      title: "Product Sales by Category",
      description: "Number of line items sold per product category",
      type: :bar,
      config: %Config{
        title: "Sales by Product Category",
        width: 700,
        height: 450,
        colors: ["#8B5CF6", "#EC4899", "#F59E0B", "#10B981", "#3B82F6"],
        show_legend: false,
        show_grid: true,
        x_axis_label: "Category",
        y_axis_label: "Units Sold",
        show_data_labels: true
      },
      data_fetcher: &fetch_product_sales_data/0
    }
  end

  defp top_products_chart do
    %{
      name: :top_products_by_revenue,
      title: "Top 10 Products by Revenue",
      description: "Top selling products ranked by total revenue generated",
      type: :bar,
      config: %Config{
        title: "Top 10 Products by Revenue",
        width: 800,
        height: 500,
        colors: ["#059669"],
        show_legend: false,
        show_grid: true,
        x_axis_label: "Product",
        y_axis_label: "Revenue ($)",
        show_data_labels: true
      },
      data_fetcher: &fetch_top_products_data/0
    }
  end

  defp fetch_chart_data(chart) do
    chart.data_fetcher.()
  end

  defp fetch_customer_status_data do
    case Ash.read(Customer) do
      {:ok, customers} ->
        data =
          customers
          |> Enum.group_by(& &1.status)
          |> Enum.map(fn {status, custs} ->
            %{
              category: status |> Atom.to_string() |> String.capitalize(),
              value: length(custs)
            }
          end)
          |> Enum.sort_by(& &1.value, :desc)

        {:ok, data}

      error ->
        error
    end
  end

  defp fetch_monthly_revenue_data do
    case Ash.read(Invoice) do
      {:ok, invoices} ->
        data =
          invoices
          |> Enum.filter(&(&1.status == :paid))
          |> Enum.group_by(fn invoice ->
            Date.beginning_of_month(invoice.date)
          end)
          |> Enum.map(fn {month, month_invoices} ->
            total =
              month_invoices
              |> Enum.reduce(Decimal.new(0), fn inv, acc ->
                Decimal.add(acc, inv.total)
              end)
              |> Decimal.to_float()

            %{x: format_month(month), y: total}
          end)
          |> Enum.sort_by(& &1.x)

        {:ok, data}

      error ->
        error
    end
  end

  defp fetch_product_sales_data do
    case Ash.read(InvoiceLineItem, load: [product: :category]) do
      {:ok, line_items} ->
        data =
          line_items
          |> Enum.filter(&(&1.product && &1.product.category))
          |> Enum.group_by(fn item -> item.product.category.name end)
          |> Enum.map(fn {category, items} ->
            %{category: category, value: length(items)}
          end)
          |> Enum.sort_by(& &1.value, :desc)

        {:ok, data}

      error ->
        error
    end
  end

  defp fetch_top_products_data do
    case Ash.read(InvoiceLineItem, load: [:product]) do
      {:ok, line_items} ->
        data =
          line_items
          |> Enum.filter(& &1.product)
          |> Enum.group_by(fn item -> item.product.name end)
          |> Enum.map(fn {product_name, items} ->
            total_revenue =
              items
              |> Enum.reduce(Decimal.new(0), fn item, acc ->
                Decimal.add(acc, item.line_total)
              end)
              |> Decimal.to_float()

            %{category: truncate_name(product_name), value: total_revenue}
          end)
          |> Enum.sort_by(& &1.value, :desc)
          |> Enum.take(10)

        {:ok, data}

      error ->
        error
    end
  end

  defp format_month(date) do
    "#{date.year}-#{String.pad_leading(to_string(date.month), 2, "0")}"
  end

  defp truncate_name(name) when is_binary(name) do
    if String.length(name) > 20 do
      String.slice(name, 0, 17) <> "..."
    else
      name
    end
  end
end
