defmodule AshReportsDemoWeb.Components.ChartTemplateViewer do
  @moduledoc """
  Component for displaying example chart definitions using AshReports DSL.

  Shows how charts would be defined within reports using the AshReports 
  chart element DSL.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :chart_name, :atom,
    required: true,
    doc: "The name of the chart to display DSL example for"

  @doc """
  Render example chart DSL for the given chart.
  """
  def chart_template_viewer(assigns) do
    template = get_chart_dsl_example(assigns.chart_name)
    assigns = assign(assigns, :template, template)

    ~H"""
    <div>
      <div class="flex items-center justify-between mb-4">
        <div>
          <h3 class="text-lg font-medium text-gray-900">
            AshReports Chart DSL Example
          </h3>
          <p class="mt-1 text-sm text-gray-600">
            How this chart would be defined within a report using AshReports DSL
          </p>
        </div>
        <button
          type="button"
          phx-click={JS.dispatch("phx:copy", to: "#chart-template-code")}
          class="inline-flex items-center px-3 py-1 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
        >
          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
          </svg>
          Copy
        </button>
      </div>

      <div class="relative" style="max-height: 600px; overflow-y: auto;">
        <pre
          id="chart-template-code"
          phx-hook="HighlightCode"
          class="bg-gray-900 text-gray-100 rounded-lg p-4 overflow-x-auto text-sm font-mono leading-relaxed"
        ><code class="language-elixir" phx-no-format><%= @template %></code></pre>
      </div>
      
      <div class="mt-4 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div class="flex">
          <svg class="w-5 h-5 text-blue-600 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
          </svg>
          <div class="text-sm text-blue-800">
            <p class="font-medium">Note:</p>
            <p class="mt-1">This chart is currently implemented using the AshReports.Charts module for data generation and rendering. The DSL shown above demonstrates how it could be defined within a report using AshReports chart elements.</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_chart_dsl_example(:customer_status_distribution) do
    """
    report :customer_status_distribution do
      title("Customer Status Distribution")
      description "Visual breakdown of customers by status"
      driving_resource(AshReportsDemo.Customer)

      band :chart_section do
        type :detail

        chart :status_chart do
          chart_type :pie
          
          data_source expr(
            records
            |> Enum.group_by(& &1.status)
            |> Enum.map(fn {status, customers} ->
              %{
                category: status |> Atom.to_string() |> String.capitalize(),
                value: length(customers)
              }
            end)
          )
          
          config %{
            title: "Customer Status Distribution",
            width: 600,
            height: 400,
            colors: ["#10B981", "#F59E0B", "#EF4444"],
            show_legend: true,
            legend_position: :right,
            show_data_labels: true
          }
          
          title "Customer Status Distribution"
          caption "Distribution of customers across different status categories"
        end
      end
    end
    """
  end

  defp get_chart_dsl_example(:monthly_revenue) do
    """
    report :monthly_revenue do
      title("Monthly Revenue Trend")
      description "Track invoice revenue trends over time"
      driving_resource(AshReportsDemo.Invoice)

      scope(fn _params ->
        import Ash.Query
        AshReportsDemo.Invoice
        |> new()
        |> filter(status == :paid)
      end)

      band :chart_section do
        type :detail

        chart :revenue_trend do
          chart_type :line
          
          data_source expr(
            records
            |> Enum.group_by(fn invoice ->
              Date.beginning_of_month(invoice.date)
            end)
            |> Enum.map(fn {month, invoices} ->
              total = Enum.reduce(invoices, Decimal.new(0), fn inv, acc ->
                Decimal.add(acc, inv.total)
              end)
              %{
                x: format_month(month),
                y: Decimal.to_float(total)
              }
            end)
          )
          
          config %{
            title: "Monthly Revenue Trend",
            width: 800,
            height: 400,
            colors: ["#3B82F6"],
            show_legend: false,
            show_grid: true,
            x_axis_label: "Month",
            y_axis_label: "Revenue ($)",
            show_data_labels: false
          }
          
          title "Monthly Revenue Trend"
          caption "Total paid invoice revenue by month"
        end
      end
    end
    """
  end

  defp get_chart_dsl_example(:product_sales_by_category) do
    """
    report :product_sales_by_category do
      title("Product Sales by Category")
      description "Analysis of product sales across categories"
      driving_resource(AshReportsDemo.InvoiceLineItem)

      band :chart_section do
        type :detail

        chart :category_sales do
          chart_type :bar
          
          data_source expr(
            records
            |> Enum.filter(&(&1.product && &1.product.category))
            |> Enum.group_by(fn item -> item.product.category.name end)
            |> Enum.map(fn {category, items} ->
              %{category: category, value: length(items)}
            end)
          )
          
          config %{
            title: "Sales by Product Category",
            width: 700,
            height: 450,
            colors: ["#8B5CF6", "#EC4899", "#F59E0B", "#10B981", "#3B82F6"],
            show_legend: false,
            show_grid: true,
            x_axis_label: "Category",
            y_axis_label: "Units Sold",
            show_data_labels: true
          }
          
          title "Product Sales by Category"
          caption "Number of line items sold per product category"
        end
      end
    end
    """
  end

  defp get_chart_dsl_example(:top_products_by_revenue) do
    """
    report :top_products_by_revenue do
      title("Top 10 Products by Revenue")
      description "Highest revenue-generating products"
      driving_resource(AshReportsDemo.InvoiceLineItem)

      band :chart_section do
        type :detail

        chart :top_products do
          chart_type :bar
          
          data_source expr(
            records
            |> Enum.filter(& &1.product)
            |> Enum.group_by(fn item -> item.product.name end)
            |> Enum.map(fn {product_name, items} ->
              total_revenue = Enum.reduce(items, Decimal.new(0), fn item, acc ->
                Decimal.add(acc, item.line_total)
              end)
              %{
                category: truncate_name(product_name),
                value: Decimal.to_float(total_revenue)
              }
            end)
            |> Enum.take(10)
          )
          
          config %{
            title: "Top 10 Products by Revenue",
            width: 800,
            height: 500,
            colors: ["#059669"],
            show_legend: false,
            show_grid: true,
            x_axis_label: "Product",
            y_axis_label: "Revenue ($)",
            show_data_labels: true
          }
          
          title "Top 10 Products by Revenue"
          caption "Top selling products ranked by total revenue"
        end
      end
    end
    """
  end

  defp get_chart_dsl_example(_), do: "# Chart DSL example not available"
end
