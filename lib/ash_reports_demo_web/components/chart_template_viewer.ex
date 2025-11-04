defmodule AshReportsDemoWeb.Components.ChartTemplateViewer do
  @moduledoc """
  Component for displaying AshReports Chart DSL definitions.

  Shows how charts should be defined using the AshReports DSL based on the
  charts and visualizations guide.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :chart_name, :atom,
    required: true,
    doc: "The name of the chart to display DSL for"

  @doc """
  Render the AshReports Chart DSL definition.
  """
  def chart_template_viewer(assigns) do
    template = get_chart_dsl(assigns.chart_name)
    assigns = assign(assigns, :template, template)

    ~H"""
    <div>
      <div class="flex items-center justify-between mb-4">
        <div>
          <h3 class="text-lg font-medium text-gray-900">
            AshReports Chart DSL
          </h3>
          <p class="mt-1 text-sm text-gray-600">
            How this chart is defined using the AshReports DSL
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
      
      <div class="mt-4 bg-amber-50 border border-amber-200 rounded-lg p-4">
        <div class="flex">
          <svg class="w-5 h-5 text-amber-600 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
          </svg>
          <div class="text-sm text-amber-800">
            <p class="font-medium">Implementation Status:</p>
            <p class="mt-1">This chart is currently implemented using programmatic generation (Charts module) due to a limitation in AshReports where the BuildReportModules transformer processes chart entities as reports. The DSL shown above represents the intended structure once this is resolved.</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_chart_dsl(:customer_status_distribution) do
    """
    defmodule MyApp.Reports do
      use Ash.Domain,
        extensions: [AshReports.Domain]

      reports do
        # Standalone pie chart definition
        pie_chart :customer_status_distribution do
          data_source expr(ChartHelpers.fetch_customer_status_distribution())

          config do
            width 600
            height 400
            title "Customer Status Distribution"
            show_percentages true
            colours ["10B981", "F59E0B", "EF4444"]
          end
        end

        # Example: Using the chart in a report band
        report :dashboard_report do
          title "Dashboard Report"
          driving_resource MyApp.Customer

          bands do
            band :status_overview do
              type :detail

              elements do
                # Reference the chart definition
                pie_chart :customer_status_distribution
              end
            end
          end
        end
      end
    end
    """
  end

  defp get_chart_dsl(:top_products_by_revenue) do
    """
    defmodule MyApp.Reports do
      use Ash.Domain,
        extensions: [AshReports.Domain]

      reports do
        # Standalone bar chart definition
        bar_chart :top_products_by_revenue do
          data_source expr(ChartHelpers.fetch_top_products_by_revenue())

          config do
            width 800
            height 500
            title "Top 10 Products by Revenue"
            type :simple
            orientation :horizontal
            data_labels true
            padding 2
            colours ["059669"]
          end
        end

        # Example: Using the chart in a report band
        report :sales_report do
          title "Sales Report"
          driving_resource MyApp.InvoiceLineItem

          bands do
            band :top_performers do
              type :detail

              elements do
                # Reference the chart definition
                bar_chart :top_products_by_revenue
              end
            end
          end
        end
      end
    end
    """
  end

  defp get_chart_dsl(:product_sales_by_category) do
    """
    defmodule MyApp.Reports do
      use Ash.Domain,
        extensions: [AshReports.Domain]

      reports do
        # Standalone bar chart definition
        bar_chart :product_sales_by_category do
          data_source expr(ChartHelpers.fetch_product_sales_by_category())

          config do
            width 700
            height 450
            title "Sales by Product Category"
            type :simple
            orientation :vertical
            data_labels true
            padding 2
            colours ["8B5CF6", "EC4899", "F59E0B", "10B981", "3B82F6"]
          end
        end

        # Example: Using the chart in a report band
        report :category_analysis do
          title "Category Analysis"
          driving_resource MyApp.InvoiceLineItem

          bands do
            band :category_breakdown do
              type :detail

              elements do
                # Reference the chart definition
                bar_chart :product_sales_by_category
              end
            end
          end
        end
      end
    end
    """
  end

  defp get_chart_dsl(:monthly_revenue) do
    """
    defmodule MyApp.Reports do
      use Ash.Domain,
        extensions: [AshReports.Domain]

      reports do
        # Standalone line chart definition
        line_chart :monthly_revenue do
          data_source expr(ChartHelpers.fetch_monthly_revenue())

          config do
            width 800
            height 400
            title "Monthly Revenue Trend"
            smoothed true
            stroke_width "2"
            colours ["3B82F6"]
          end
        end

        # Example: Using the chart in a report band
        report :revenue_report do
          title "Revenue Report"
          driving_resource MyApp.Invoice

          scope(fn _params ->
            import Ash.Query
            MyApp.Invoice
            |> new()
            |> filter(status == :paid)
          end)

          bands do
            band :revenue_trends do
              type :detail

              elements do
                # Reference the chart definition
                line_chart :monthly_revenue
              end
            end
          end
        end
      end
    end
    """
  end

  defp get_chart_dsl(_), do: "# Chart DSL not available for this chart"
end
