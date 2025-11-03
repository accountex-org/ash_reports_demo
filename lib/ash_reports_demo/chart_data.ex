defmodule AshReportsDemo.ChartData do
  @moduledoc """
  Data fetcher functions for charts defined in the AshReports DSL.

  Each function queries Ash resources and returns data formatted for specific chart types:
  - Pie/Bar charts: `[%{category: string, value: number}, ...]`
  - Line/Area charts: `[%{x: string|number, y: number}, ...]`
  - Scatter charts: `[%{x: number, y: number}, ...]`
  - Gantt charts: `[%{task: string, start_date: Date.t(), end_date: Date.t()}, ...]`
  - Sparklines: `[number, ...]`
  """

  alias AshReportsDemo.{Customer, Invoice, Product, InvoiceLineItem, Inventory}

  @doc """
  Fetches customer distribution by status for pie chart.
  Returns: `[%{category: "Active", value: 150}, ...]`
  """
  def fetch_customer_status_data do
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

  @doc """
  Fetches monthly revenue trend for line chart.
  Returns: `[%{x: "2024-01", y: 15000.50}, ...]`
  """
  def fetch_monthly_revenue_data do
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

  @doc """
  Fetches product sales by category for bar chart.
  Returns: `[%{category: "Electronics", value: 245}, ...]`
  """
  def fetch_product_sales_data do
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

  @doc """
  Fetches top 10 products by revenue for horizontal bar chart.
  Returns: `[%{category: "Product Name", value: 12500.00}, ...]`
  """
  def fetch_top_products_data do
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

  @doc """
  Fetches inventory levels over time for area chart.
  Returns: `[%{x: "2024-01", y: 1500}, ...]`

  Note: Since we don't track historical inventory, this simulates monthly snapshots
  based on current inventory levels with random variation.
  """
  def fetch_inventory_levels_data do
    case Ash.read(Inventory) do
      {:ok, inventory_records} ->
        # Get current total inventory
        current_total =
          inventory_records
          |> Enum.reduce(0, fn inv, acc -> acc + inv.quantity_on_hand end)

        # Generate 12 months of simulated data showing inventory trends
        today = Date.utc_today()

        data =
          0..11
          |> Enum.map(fn months_ago ->
            date = Date.add(today, -months_ago * 30)
            # Simulate historical variation (current ± 20%)
            variation = :rand.uniform(40) - 20
            quantity = max(0, current_total + div(current_total * variation, 100))

            %{x: format_month(date), y: quantity}
          end)
          |> Enum.reverse()

        {:ok, data}

      error ->
        error
    end
  end

  @doc """
  Fetches price vs quantity correlation for scatter chart.
  Returns: `[%{x: 29.99, y: 145}, ...]`

  X-axis: Product price
  Y-axis: Total quantity sold
  """
  def fetch_price_quantity_data do
    with {:ok, line_items} <- Ash.read(InvoiceLineItem, load: [:product]),
         {:ok, products} <- Ash.read(Product) do
      # Group line items by product to get total quantities sold
      sales_by_product =
        line_items
        |> Enum.filter(& &1.product)
        |> Enum.group_by(& &1.product_id)
        |> Enum.map(fn {product_id, items} ->
          total_qty = Enum.reduce(items, 0, fn item, acc -> acc + item.quantity end)
          {product_id, total_qty}
        end)
        |> Map.new()

      # Map products to price/quantity coordinates
      data =
        products
        |> Enum.filter(&Map.has_key?(sales_by_product, &1.id))
        |> Enum.map(fn product ->
          %{
            x: Decimal.to_float(product.price),
            y: Map.get(sales_by_product, product.id, 0)
          }
        end)
        |> Enum.filter(&(&1.y > 0))

      {:ok, data}
    else
      error -> error
    end
  end

  @doc """
  Fetches invoice payment timelines for gantt chart.
  Returns: `[%{task: "INV-001", start_date: ~D[2024-01-01], end_date: ~D[2024-01-15]}, ...]`

  Shows invoice date as start and due date as end for the top 20 recent invoices.
  """
  def fetch_payment_timeline_data do
    case Ash.read(Invoice) do
      {:ok, invoices} ->
        data =
          invoices
          |> Enum.filter(&(&1.status in [:sent, :paid, :overdue]))
          |> Enum.sort_by(& &1.date, {:desc, Date})
          |> Enum.take(20)
          |> Enum.map(fn invoice ->
            # Calculate due date (30 days from invoice date as default)
            due_date = Date.add(invoice.date, 30)

            %{
              task: invoice.invoice_number,
              start_date: invoice.date,
              end_date: due_date
            }
          end)
          |> Enum.reverse()

        {:ok, data}

      error ->
        error
    end
  end

  @doc """
  Fetches customer health score trend for sparkline.
  Returns: `[75, 78, 72, 80, 85, 82, 88]`

  Note: Returns average health scores for the last 7 "periods" (simulated).
  """
  def fetch_health_sparkline_data do
    case Ash.read(Customer, load: [:customer_health_score]) do
      {:ok, customers} ->
        # Get current average health score
        current_avg =
          customers
          |> Enum.map(& &1.customer_health_score)
          |> Enum.sum()
          |> then(&div(&1, max(length(customers), 1)))

        # Simulate 7 data points with minor variations
        data =
          1..7
          |> Enum.map(fn _ ->
            variation = :rand.uniform(10) - 5
            max(0, min(100, current_avg + variation))
          end)

        {:ok, data}

      error ->
        error
    end
  end

  # Private helper functions

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
