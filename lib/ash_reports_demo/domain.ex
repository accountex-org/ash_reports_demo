defmodule AshReportsDemo.Domain do
  @moduledoc """
  Ash Domain for AshReports Demo application.

  Defines the business domain with resources, reports, and policies
  for the comprehensive invoicing system demonstration.
  """

  use Ash.Domain, extensions: [AshReports.Domain]

  import Ash.Expr

  resources do
    # Phase 7.2: Business resources
    resource AshReportsDemo.Customer
    resource AshReportsDemo.CustomerAddress
    resource AshReportsDemo.CustomerType
    resource AshReportsDemo.Product
    resource AshReportsDemo.ProductCategory
    resource AshReportsDemo.Inventory
    resource AshReportsDemo.Invoice
    resource AshReportsDemo.InvoiceLineItem
  end

  reports do
    # Chart Definitions - Demonstrating all 7 AshReports chart types
    # Charts are defined at the reports level as siblings to report definitions

    # 1. Customer Status Distribution - Pie Chart
    pie_chart :customer_status_distribution do
      data_source(fn ->
        source_records =
          AshReportsDemo.Customer
          |> Ash.Query.new()
          |> Ash.read!(domain: AshReportsDemo.Domain)

        chart_data =
          source_records
          |> Enum.group_by(& &1.status)
          |> Enum.map(fn {status, customers} ->
            %{
              category: status |> Atom.to_string() |> String.capitalize(),
              value: length(customers)
            }
          end)
          |> Enum.sort_by(& &1.value, :desc)

        {:ok, chart_data, %{source_records: length(source_records)}}
      end)

      config do
        width 600
        height 400
        title "Customer Status Distribution"
        data_labels true
        colours ["10B981", "F59E0B", "EF4444"]
      end
    end

    # 2. Monthly Revenue Trend - Line Chart
    line_chart :monthly_revenue do
      data_source(fn ->
        require Ash.Query

        source_records =
          AshReportsDemo.Invoice
          |> Ash.Query.new()
          |> Ash.Query.filter(expr(status == :paid))
          |> Ash.read!(domain: AshReportsDemo.Domain)

        chart_data =
          source_records
          |> Enum.group_by(fn invoice -> Date.beginning_of_month(invoice.date) end)
          |> Enum.map(fn {month, invoices} ->
            total =
              invoices
              |> Enum.reduce(Decimal.new(0), fn inv, acc -> Decimal.add(acc, inv.total) end)
              |> Decimal.to_float()

            %{
              x: "#{month.year}-#{String.pad_leading(to_string(month.month), 2, "0")}",
              y: total
            }
          end)
          |> Enum.sort_by(& &1.x)

        {:ok, chart_data, %{source_records: length(source_records)}}
      end)

      config do
        width 800
        height 400
        title "Monthly Revenue Trend"
        smoothed true
        stroke_width "2"
        axis_label_rotation :auto
        colours ["3B82F6"]
      end
    end

    # 3. Product Sales by Category - Bar Chart (Vertical)
    bar_chart :product_sales_by_category do
      data_source(fn ->
        require Logger
        start = System.monotonic_time(:millisecond)

        # Step 1: Load all line items (just IDs and product_id)
        Logger.info("Loading line items...")
        source_records =
          AshReportsDemo.InvoiceLineItem
          |> Ash.Query.new()
          |> Ash.read!(domain: AshReportsDemo.Domain)

        step1_time = System.monotonic_time(:millisecond) - start
        Logger.info("Loaded #{length(source_records)} line items in #{step1_time}ms")

        # Step 2: Get unique product IDs
        step2_start = System.monotonic_time(:millisecond)
        product_ids =
          source_records
          |> Enum.map(& &1.product_id)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        step2_time = System.monotonic_time(:millisecond) - step2_start
        Logger.info("Found #{length(product_ids)} unique products in #{step2_time}ms")

        # Step 3: Load products with categories
        step3_start = System.monotonic_time(:millisecond)
        products =
          AshReportsDemo.Product
          |> Ash.Query.new()
          |> Ash.Query.load(:category)
          |> Ash.read!(domain: AshReportsDemo.Domain)

        products_with_categories =
          products
          |> Enum.filter(&(&1.id in product_ids && &1.category))
          |> Map.new(fn product -> {product.id, product.category.name} end)

        step3_time = System.monotonic_time(:millisecond) - step3_start
        Logger.info("Loaded products with categories in #{step3_time}ms")

        # Step 4: Group line items by category
        step4_start = System.monotonic_time(:millisecond)
        filtered_records =
          source_records
          |> Enum.filter(&Map.has_key?(products_with_categories, &1.product_id))

        chart_data =
          filtered_records
          |> Enum.group_by(fn item -> products_with_categories[item.product_id] end)
          |> Enum.map(fn {category, items} ->
            %{category: category, value: length(items)}
          end)
          |> Enum.sort_by(& &1.value, :desc)

        step4_time = System.monotonic_time(:millisecond) - step4_start
        total_time = System.monotonic_time(:millisecond) - start
        Logger.info("Grouped data in #{step4_time}ms. Total: #{total_time}ms")

        {:ok, chart_data, %{source_records: length(filtered_records)}}
      end)

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

    # 4. Top Products by Revenue - Bar Chart (Horizontal)
    bar_chart :top_products_by_revenue do
      data_source(fn ->
        source_records =
          AshReportsDemo.InvoiceLineItem
          |> Ash.Query.new()
          |> Ash.Query.load(:product)
          |> Ash.read!(domain: AshReportsDemo.Domain)

        filtered_records = Enum.filter(source_records, & &1.product)

        chart_data =
          filtered_records
          |> Enum.group_by(fn item -> item.product.name end)
          |> Enum.map(fn {product_name, items} ->
            total_revenue =
              items
              |> Enum.reduce(Decimal.new(0), fn item, acc -> Decimal.add(acc, item.line_total) end)
              |> Decimal.to_float()

            truncated_name =
              if String.length(product_name) > 20,
                do: String.slice(product_name, 0, 17) <> "...",
                else: product_name

            %{category: truncated_name, value: total_revenue}
          end)
          |> Enum.sort_by(& &1.value, :desc)
          |> Enum.take(10)

        {:ok, chart_data, %{source_records: length(filtered_records)}}
      end)

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

    # 5. Inventory Levels Over Time - Area Chart
    area_chart :inventory_levels_over_time do
      data_source(fn ->
        source_records =
          AshReportsDemo.Inventory
          |> Ash.Query.new()
          |> Ash.read!(domain: AshReportsDemo.Domain)

        current_total =
          source_records
          |> Enum.reduce(0, fn inv, acc -> acc + inv.quantity_on_hand end)

        # Simulate 12 months of historical inventory data
        today = Date.utc_today()

        chart_data =
          0..11
          |> Enum.map(fn months_ago ->
            date = Date.add(today, -months_ago * 30)
            # Simulate historical variation (current ± 20%)
            variation = :rand.uniform(40) - 20
            quantity = Kernel.max(0, current_total + div(current_total * variation, 100))

            %{
              x: "#{date.year}-#{String.pad_leading(to_string(date.month), 2, "0")}",
              y: quantity
            }
          end)
          |> Enum.reverse()

        {:ok, chart_data, %{source_records: length(source_records)}}
      end)

      config do
        width 800
        height 400
        title "Inventory Levels Trend"
        mode :simple
        opacity 0.7
        smooth_lines true
        colours ["10B981"]
      end
    end

    # 6. Price vs Quantity Analysis - Scatter Chart
    scatter_chart :price_quantity_analysis do
      data_source(fn ->
        # Get sales quantities by product
        source_records =
          AshReportsDemo.InvoiceLineItem
          |> Ash.Query.new()
          |> Ash.Query.load(:product)
          |> Ash.read!(domain: AshReportsDemo.Domain)

        filtered_records = Enum.filter(source_records, & &1.product)

        sales_by_product =
          filtered_records
          |> Enum.group_by(& &1.product_id)
          |> Enum.map(fn {product_id, items} ->
            total_qty = Enum.reduce(items, 0, fn item, acc -> acc + item.quantity end)
            {product_id, total_qty}
          end)
          |> Map.new()

        # Map products to price/quantity coordinates
        chart_data =
          AshReportsDemo.Product
          |> Ash.Query.new()
          |> Ash.read!(domain: AshReportsDemo.Domain)
          |> Enum.filter(&Map.has_key?(sales_by_product, &1.id))
          |> Enum.map(fn product ->
            %{
              x: Decimal.to_float(product.price),
              y: Map.get(sales_by_product, product.id, 0)
            }
          end)
          |> Enum.filter(&(&1.y > 0))

        {:ok, chart_data, %{source_records: length(filtered_records)}}
      end)

      config do
        width 700
        height 500
        title "Price vs Quantity Correlation"
        axis_label_rotation :auto
        colours ["8B5CF6"]
      end
    end

    # 7. Invoice Payment Timeline - Gantt Chart
    gantt_chart :invoice_payment_timeline do
      data_source(fn ->
        require Ash.Query

        source_records =
          AshReportsDemo.Invoice
          |> Ash.Query.new()
          |> Ash.Query.filter(expr(status in [:sent, :paid, :overdue]))
          |> Ash.Query.sort(date: :desc)
          |> Ash.Query.limit(20)
          |> Ash.read!(domain: AshReportsDemo.Domain)

        chart_data =
          source_records
          |> Enum.map(fn invoice ->
            # Calculate due date (30 days from invoice date)
            due_date = Date.add(invoice.date, 30)

            %{
              task: invoice.invoice_number,
              start_date: invoice.date,
              end_date: due_date
            }
          end)
          |> Enum.reverse()

        {:ok, chart_data, %{source_records: length(source_records)}}
      end)

      config do
        width 900
        height 400
        title "Invoice Payment Timeline"
        show_task_labels true
        padding 2
        colours ["3B82F6"]
      end
    end

    # 8. Customer Health Trend - Sparkline
    sparkline :customer_health_trend do
      data_source(fn ->
        source_records =
          AshReportsDemo.Customer
          |> Ash.Query.new()
          |> Ash.Query.load(:customer_health_score)
          |> Ash.read!(domain: AshReportsDemo.Domain)

        current_avg =
          source_records
          |> then(fn customers ->
            total = Enum.reduce(customers, 0, fn c, acc -> acc + c.customer_health_score end)
            div(total, Kernel.max(length(customers), 1))
          end)

        # Simulate 7 data points with minor variations
        chart_data =
          1..7
          |> Enum.map(fn _ ->
            variation = :rand.uniform(10) - 5
            Kernel.max(0, Kernel.min(100, current_avg + variation))
          end)

        {:ok, chart_data, %{source_records: length(source_records)}}
      end)

      config do
        width 150
        height 30
        spot_radius 2
        spot_colour "red"
        line_width 1
        line_colour "rgba(0, 200, 50, 0.7)"
        fill_colour "rgba(0, 200, 50, 0.2)"
      end
    end

    # Phase 7.5: Comprehensive report definitions demonstrating all AshReports features

    # Customer Summary Report - Multi-level grouping with business intelligence
    report :customer_summary do
      title("Customer Summary Report")
      description "Comprehensive customer analysis with geographic and tier grouping"
      driving_resource(AshReportsDemo.Customer)

      # Scope expression to filter data based on parameters
      scope(fn params ->
        import Ash.Query

        AshReportsDemo.Customer
        |> new()
        |> then(fn query ->
          # Filter by customer status (include_inactive parameter)
          if params[:include_inactive] do
            query
          else
            query |> filter(status == :active)
          end
        end)
        |> then(fn query ->
          # Filter by region if provided
          # Map region atoms to state lists for filtering
          case params[:region] do
            :west ->
              query
              |> filter(
                exists(
                  addresses,
                  state in [
                    "CA",
                    "OR",
                    "WA",
                    "NV",
                    "AZ",
                    "UT",
                    "ID",
                    "MT",
                    "WY",
                    "CO",
                    "NM",
                    "AK",
                    "HI"
                  ]
                )
              )

            :northeast ->
              query
              |> filter(
                exists(addresses, state in ["ME", "NH", "VT", "MA", "RI", "CT", "NY", "NJ", "PA"])
              )

            :southeast ->
              query
              |> filter(
                exists(
                  addresses,
                  state in [
                    "MD",
                    "DE",
                    "VA",
                    "WV",
                    "KY",
                    "NC",
                    "SC",
                    "TN",
                    "GA",
                    "FL",
                    "AL",
                    "MS",
                    "LA",
                    "AR"
                  ]
                )
              )

            :south ->
              query |> filter(exists(addresses, state in ["TX", "OK"]))

            :midwest ->
              query
              |> filter(
                exists(
                  addresses,
                  state in [
                    "OH",
                    "IN",
                    "IL",
                    "MI",
                    "WI",
                    "MN",
                    "IA",
                    "MO",
                    "ND",
                    "SD",
                    "NE",
                    "KS"
                  ]
                )
              )

            :mountain_west ->
              query
              |> filter(
                exists(addresses, state in ["MT", "ID", "WY", "NV", "UT", "CO", "AZ", "NM"])
              )

            _ ->
              query
          end
        end)
        |> then(fn query ->
          # Filter by tier if provided
          # Customer tier is based on credit_limit (see Customer resource calculations)
          # Platinum: >= 50000, Gold: >= 25000, Silver: >= 10000, Bronze: < 10000
          case params[:tier] do
            "Platinum" ->
              query |> filter(credit_limit >= ^Decimal.new("50000"))

            "Gold" ->
              query
              |> filter(
                credit_limit >= ^Decimal.new("25000") and credit_limit < ^Decimal.new("50000")
              )

            "Silver" ->
              query
              |> filter(
                credit_limit >= ^Decimal.new("10000") and credit_limit < ^Decimal.new("25000")
              )

            "Bronze" ->
              query |> filter(credit_limit < ^Decimal.new("10000"))

            _ ->
              query
          end
        end)
        |> then(fn query ->
          # Filter by minimum health score if provided
          # Note: Since health_score is a calculation, we filter by the primary factor (status)
          # Active customers generally have scores >= 70, inactive >= 30, suspended < 30
          min_score = params[:min_health_score] || 0

          cond do
            min_score >= 70 ->
              # Only active customers can have scores >= 70
              query |> filter(status == :active)

            min_score >= 30 ->
              # Active or inactive customers
              query |> filter(status in [:active, :inactive])

            true ->
              # Any status
              query
          end
        end)
      end)

      parameter(:region, :atom,
        constraints: [
          one_of: [:west, :northeast, :southeast, :south, :midwest, :mountain_west, :other]
        ]
      )

      parameter(:tier, :atom, constraints: [one_of: [:bronze, :silver, :gold, :platinum]])
      parameter(:min_health_score, :integer, default: 0, constraints: [min: 0, max: 100])
      parameter(:include_inactive, :boolean, default: false)

      variable :customer_count do
        type :count
        expression(expr(1))
        reset_on(:report)
      end

      variable :total_lifetime_value do
        type :sum
        expression(expr(lifetime_value))
        reset_on(:report)
      end

      group :region do
        level(1)
        expression(expr(addresses.state))
      end

      band :title do
        type :title

        label :report_title do
          text("Customer Summary Report")
        end
      end

      band :customer_detail do
        type :detail

        field :customer_name do
          source :name
        end

        field :health_score do
          source :customer_health_score
        end

        field :tier do
          source :customer_tier
        end
      end

      band :summary do
        type :summary

        label :total_customers do
          text("Total Customers: [customer_count]")
        end

        label :total_value do
          text("Total Lifetime Value: [total_lifetime_value]")
        end
      end
    end

    # Product Inventory Report - Profitability analytics
    report :product_inventory do
      title("Product Inventory Report")
      description "Inventory analysis with profitability metrics"
      driving_resource(AshReportsDemo.Product)

      # Scope expression to filter products based on parameters
      scope(fn params ->
        import Ash.Query

        AshReportsDemo.Product
        |> new()
        |> then(fn query ->
          # Filter by product status (include_inactive parameter)
          if params[:include_inactive] do
            query
          else
            query |> filter(active == true)
          end
        end)
        |> then(fn query ->
          # Filter by category if provided
          if category_name = params[:category_name] do
            category_name_str =
              category_name
              |> Atom.to_string()
              |> String.replace("_", " ")
              |> String.split()
              |> Enum.map_join(" ", &String.capitalize/1)

            categories = Ash.read!(AshReportsDemo.ProductCategory)
            category = Enum.find(categories, fn c -> c.name == category_name_str end)

            if category do
              query |> filter(category_id == ^category.id)
            else
              query
            end
          else
            query
          end
        end)
      end)

      parameter(:category_name, :atom,
        constraints: [one_of: [:books, :clothing, :electronics, :home_garden, :sports]]
      )

      parameter(:include_inactive, :boolean, default: false)

      variable :total_products do
        type :count
        expression(expr(1))
        reset_on(:report)
      end

      variable :total_inventory_value do
        type :sum
        expression(expr(price))
        reset_on(:report)
      end

      band :title do
        type :title

        label :report_title do
          text("Product Inventory Report")
        end
      end

      band :product_detail do
        type :detail

        field :product_name do
          source :name
        end

        field :sku do
          source :sku
        end

        field :price do
          source :price
        end

        field :margin do
          source :margin_percentage
        end
      end

      band :inventory_summary do
        type :summary

        label :total_products_summary do
          text("Total Products: [total_products]")
        end

        label :inventory_value_summary do
          text("Total Inventory Value: [total_inventory_value]")
        end
      end
    end

    # Invoice Details Report - Master-detail financial analysis
    report :invoice_details do
      title("Invoice Details Report")
      description "Comprehensive invoice analysis with payment performance"
      driving_resource(AshReportsDemo.Invoice)

      # Scope expression to filter invoices based on parameters
      scope(fn params ->
        import Ash.Query

        AshReportsDemo.Invoice
        |> new()
        |> then(fn query ->
          # Filter by invoice status if provided
          if status = params[:status] do
            query |> filter(status == ^status)
          else
            query
          end
        end)
        |> then(fn query ->
          # Filter by customer if provided
          if customer_id = params[:customer_id] do
            query |> filter(customer_id == ^customer_id)
          else
            query
          end
        end)
        |> then(fn query ->
          # Exclude paid invoices if include_paid is false
          if params[:include_paid] do
            query
          else
            query |> filter(status != :paid)
          end
        end)
      end)

      parameter(:status, :atom,
        constraints: [one_of: [:draft, :sent, :paid, :overdue, :cancelled]]
      )

      parameter(:customer_id, :uuid)
      parameter(:include_paid, :boolean, default: true)

      variable :total_invoices do
        type :count
        expression(expr(1))
        reset_on(:report)
      end

      variable :total_invoice_amount do
        type :sum
        expression(expr(total))
        reset_on(:report)
      end

      band :title do
        type :title

        label :report_title do
          text("Invoice Details Report")
        end
      end

      band :invoice_detail do
        type :detail

        field :invoice_number do
          source :invoice_number
        end

        field :date do
          source :date
        end

        field :status do
          source :status
        end

        field :total do
          source :total
        end
      end

      band :financial_summary do
        type :summary

        label :invoice_metrics do
          text("Total Invoices: [total_invoices] | Total Amount: [total_invoice_amount]")
        end
      end
    end

    # Financial Summary Report - Executive dashboard
    report :financial_summary do
      title("Executive Financial Summary")
      description "Comprehensive financial dashboard with business intelligence"
      driving_resource(AshReportsDemo.Invoice)

      # Scope expression to filter invoices based on fiscal period
      scope(fn params ->
        import Ash.Query

        fiscal_year = params[:fiscal_year] || 2024
        period_type = params[:period_type] || :monthly

        # Calculate date range based on period type
        {start_date, end_date} =
          case period_type do
            :yearly ->
              {Date.new!(fiscal_year, 1, 1), Date.new!(fiscal_year, 12, 31)}

            :quarterly ->
              {Date.new!(fiscal_year, 1, 1), Date.new!(fiscal_year, 3, 31)}

            :monthly ->
              {Date.new!(fiscal_year, 1, 1), Date.new!(fiscal_year, 1, 31)}

            _ ->
              {Date.new!(fiscal_year, 1, 1), Date.new!(fiscal_year, 12, 31)}
          end

        AshReportsDemo.Invoice
        |> new()
        |> filter(date >= ^start_date and date <= ^end_date)
        |> filter(status in [:sent, :paid, :overdue])
      end)

      parameter(:period_type, :atom,
        default: :monthly,
        constraints: [one_of: [:monthly, :quarterly, :yearly]]
      )

      parameter(:fiscal_year, :integer, default: 2024)

      variable :total_revenue do
        type :sum
        expression(expr(total))
        reset_on(:report)
      end

      variable :invoice_count do
        type :count
        expression(expr(1))
        reset_on(:report)
      end

      band :executive_title do
        type :title

        label :report_title do
          text("Executive Financial Summary")
        end
      end

      band :invoice_details do
        type :detail

        field :invoice_number do
          source :invoice_number
        end

        field :date do
          source :date
        end

        field :total do
          source :total
        end
      end

      band :executive_summary do
        type :summary

        label :revenue_summary do
          text("Total Revenue: [total_revenue] across [invoice_count] transactions")
        end
      end
    end
  end

  authorization do
    # Phase 7.4: Will be implemented with policy-based authorization
    authorize :when_requested
  end
end
