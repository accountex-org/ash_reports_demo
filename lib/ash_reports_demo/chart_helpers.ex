defmodule AshReportsDemo.ChartHelpers do
  @moduledoc """
  Helper functions for chart data_source expressions in the Domain DSL.

  These functions are referenced in chart definitions using &Module.function/arity format
  since Ash expr() doesn't support inline anonymous functions.
  """

  alias AshReportsDemo.{Customer, Invoice, InvoiceLineItem}

  def fetch_customer_status_distribution do
    Customer
    |> Ash.read!()
    |> Enum.group_by(& &1.status)
    |> Enum.map(fn {status, customers} ->
      %{
        category: status |> Atom.to_string() |> String.capitalize(),
        value: length(customers)
      }
    end)
    |> Enum.sort_by(& &1.value, :desc)
  end

  def fetch_top_products_by_revenue do
    InvoiceLineItem
    |> Ash.read!(load: [:product])
    |> Enum.filter(& &1.product)
    |> Enum.group_by(fn item -> item.product.name end)
    |> Enum.map(fn {product_name, items} ->
      total =
        items
        |> Enum.reduce(Decimal.new(0), fn item, acc ->
          Decimal.add(acc, item.line_total)
        end)
        |> Decimal.to_float()

      name =
        if String.length(product_name) > 20 do
          String.slice(product_name, 0, 17) <> "..."
        else
          product_name
        end

      %{category: name, value: total}
    end)
    |> Enum.sort_by(& &1.value, :desc)
    |> Enum.take(10)
  end

  def fetch_product_sales_by_category do
    InvoiceLineItem
    |> Ash.read!(load: [product: :category])
    |> Enum.filter(&(&1.product && &1.product.category))
    |> Enum.group_by(fn item -> item.product.category.name end)
    |> Enum.map(fn {category, items} ->
      %{category: category, value: length(items)}
    end)
    |> Enum.sort_by(& &1.value, :desc)
  end

  def fetch_monthly_revenue do
    Invoice
    |> Ash.read!()
    |> Enum.filter(&(&1.status == :paid))
    |> Enum.group_by(fn invoice ->
      Date.beginning_of_month(invoice.date)
    end)
    |> Enum.map(fn {month, invoices} ->
      total =
        invoices
        |> Enum.reduce(Decimal.new(0), fn inv, acc ->
          Decimal.add(acc, inv.total)
        end)
        |> Decimal.to_float()

      month_str = "#{month.year}-#{String.pad_leading(to_string(month.month), 2, "0")}"
      %{x: month_str, y: total}
    end)
    |> Enum.sort_by(& &1.x)
  end
end
