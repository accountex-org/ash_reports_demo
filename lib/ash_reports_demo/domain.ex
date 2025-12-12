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

    # Session tracking resources
    resource AshReportsDemo.SessionMetrics
    resource AshReportsDemo.SessionSnapshot

    # Telemetry resources
    resource AshReportsDemo.Resources.TelemetryEvent
    resource AshReportsDemo.Resources.TelemetryMetric
  end

  reports do
    # Chart Definitions - Demonstrating all 7 AshReports chart types
    # Charts are defined at the reports level as siblings to report definitions

    # 1. Customer Status Distribution - Pie Chart (DECLARATIVE)
    pie_chart :customer_status_distribution do
      driving_resource(AshReportsDemo.Customer)

      transform do
        group_by(:status)
        aggregates([{:count, nil, :count}])
        as_category(:group_key)
        as_value(:count)
        sort_by({:count, :desc})
      end

      config do
        width(600)
        height(400)
        title("Customer Status Distribution")
        data_labels(true)
        colours(["10B981", "F59E0B", "EF4444"])
      end
    end

    # 2. Monthly Revenue Trend - Line Chart (DECLARATIVE)
    line_chart :monthly_revenue do
      driving_resource(AshReportsDemo.Invoice)

      transform do
        group_by({:date, :month})
        aggregates([{:sum, :total, :total}])
        filters(%{status: :paid})
        as_x(:group_key)
        as_y(:total)
        sort_by({:group_key, :asc})
      end

      config do
        width(800)
        height(400)
        title("Monthly Revenue Trend")
        smoothed(true)
        stroke_width("2")
        axis_label_rotation(:auto)
        colours(["3B82F6"])
      end
    end

    # 3. Product Sales by Category - Bar Chart (Vertical) (DECLARATIVE)
    bar_chart :product_sales_by_category do
      driving_resource(AshReportsDemo.InvoiceLineItem)

      transform do
        group_by({:product, :category, :name})
        aggregates([{:count, nil, :count}])
        as_category(:group_key)
        as_value(:count)
        sort_by({:count, :desc})
      end

      load_relationships([:product, {:product, :category}])

      config do
        width(700)
        height(450)
        title("Sales by Product Category")
        type :simple
        orientation(:vertical)
        data_labels(true)
        padding(2)
        colours(["8B5CF6", "EC4899", "F59E0B", "10B981", "3B82F6"])
      end
    end

    # 4. Top Products by Revenue - Bar Chart (Horizontal) (DECLARATIVE)
    bar_chart :top_products_by_revenue do
      driving_resource(AshReportsDemo.InvoiceLineItem)

      transform do
        group_by({:product, :name})
        aggregates([{:sum, :line_total, :total_revenue}])
        as_category(:group_key)
        as_value(:total_revenue)
        sort_by({:total_revenue, :desc})
        limit 10
      end

      load_relationships([:product])

      config do
        width(800)
        height(500)
        title("Top 10 Products by Revenue")
        type :simple
        orientation(:horizontal)
        data_labels(true)
        padding(2)
        colours(["059669"])
      end
    end

    # 5. Inventory Levels Over Time - Area Chart (DECLARATIVE)
    area_chart :inventory_levels_over_time do
      driving_resource(AshReportsDemo.Inventory)

      transform do
        group_by({:last_received_date, :month})
        aggregates([{:sum, :current_stock, :quantity}])
        as_x(:group_key)
        as_y(:quantity)
        sort_by({:group_key, :asc})
      end

      config do
        width(800)
        height(400)
        title("Inventory Levels Trend")
        mode(:simple)
        opacity(0.7)
        smooth_lines(true)
        colours(["10B981"])
      end
    end

    # 6. Price vs Quantity Analysis - Scatter Chart (DECLARATIVE)
    scatter_chart :price_quantity_analysis do
      driving_resource(AshReportsDemo.InvoiceLineItem)

      transform do
        group_by(:product_id)
        aggregates([{:sum, :quantity, :total_quantity}])
        as_x({:product, :price})
        as_y(:total_quantity)
      end

      load_relationships([:product])

      config do
        width(700)
        height(500)
        title("Price vs Quantity Correlation")
        axis_label_rotation(:auto)
        colours(["8B5CF6"])
      end
    end

    # 7. Invoice Payment Timeline - Gantt Chart (DECLARATIVE)
    gantt_chart :invoice_payment_timeline do
      driving_resource(AshReportsDemo.Invoice)

      transform do
        filters(%{status: [:sent, :paid, :overdue]})
        as_category(:status)
        as_task(:invoice_number)
        as_start_date(:date)
        as_end_date({:date, :add_days, 30})
        sort_by({:date, :desc})
        limit 20
      end

      config do
        width(900)
        height(400)
        title("Invoice Payment Timeline")
        show_task_labels(true)
        padding(2)
        colours(["3B82F6", "10B981", "F59E0B"])
      end
    end

    # Phase 7.5: Comprehensive report definitions demonstrating all AshReports features

    # Customer Summary Report - Multi-level grouping with business intelligence
    report :customer_summary do
      title("Customer Summary Report")
      description "Comprehensive customer analysis with geographic and tier grouping"
      driving_resource(AshReportsDemo.Customer)

      # Base filter to pre-filter data based on parameters
      base_filter(fn params ->
        import Ash.Query

        AshReportsDemo.Customer
        |> new()
        |> then(fn query ->
          # Filter by dataset_id for multi-dataset support
          case params[:dataset_id] do
            nil -> query
            dataset_id -> query |> filter(dataset_id == ^dataset_id)
          end
        end)
        |> then(fn query ->
          # Filter by customer status (include_inactive parameter)
          if params[:include_inactive] do
            query
          else
            query |> filter(status == :active)
          end
        end)
        |> then(fn query ->
          # Filter by region if provided using region_name attribute
          case params[:region] do
            :west -> query |> filter(region_name == "West")
            :northeast -> query |> filter(region_name == "Northeast")
            :southeast -> query |> filter(region_name == "Southeast")
            :southwest -> query |> filter(region_name == "Southwest")
            :midwest -> query |> filter(region_name == "Midwest")
            _ -> query
          end
        end)
        |> then(fn query ->
          # Filter by tier if provided
          # Customer tier is based on credit_limit (see Customer resource calculations)
          # Platinum: >= 50000, Gold: >= 25000, Silver: >= 10000, Bronze: < 10000
          case params[:tier] do
            :platinum ->
              query |> filter(credit_limit >= ^Decimal.new("50000"))

            :gold ->
              query
              |> filter(
                credit_limit >= ^Decimal.new("25000") and credit_limit < ^Decimal.new("50000")
              )

            :silver ->
              query
              |> filter(
                credit_limit >= ^Decimal.new("10000") and credit_limit < ^Decimal.new("25000")
              )

            :bronze ->
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
        |> Ash.Query.load([
          :addresses,
          :customer_health_score,
          :customer_tier,
          :lifetime_value,
          :region_name
        ])
        # Note: Can only sort by attributes, not function-based calculations
        |> Ash.Query.sort([region_name: :asc])
      end)

      # Dataset parameter for multitenancy filtering
      parameter(:dataset_id, :string)

      parameter(:region, :atom,
        constraints: [
          one_of: [:west, :northeast, :southeast, :southwest, :midwest]
        ]
      )

      parameter(:tier, :atom, constraints: [one_of: [:bronze, :silver, :gold, :platinum]])
      parameter(:min_health_score, :integer, default: 0, constraints: [min: 0, max: 100])
      parameter(:include_inactive, :boolean, default: false)

      # Report-level variables
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

      # Group-level variables (reset on each group)
      variable :group_customer_count do
        type :count
        expression(expr(1))
        reset_on(:group)
      end

      variable :group_total_credit_limit do
        type :sum
        expression(expr(credit_limit))
        reset_on(:group)
      end

      variable :group_avg_health_score do
        type :average
        expression(expr(customer_health_score))
        reset_on(:group)
      end

      group :region do
        level(1)
        expression(expr(region_name))
      end

      band :title do
        type :title

        grid :title_grid do
          columns ["1fr"]
          align {:center, :horizon}
          inset "10pt"

          label :report_title do
            text("Customer Summary Report")
            style font_size: 24, font_weight: "bold", color: "blue"
          end
        end
      end

      band :group_header do
        type :group_header
        group_level(1)

        grid :region_header_grid do
          columns ["1fr"]
          inset "5pt"

          label :region_header do
            text("Region: [group_value]")
            style font_weight: "bold", color: "blue"
          end
        end

        table :column_header_table do
          columns ["150pt", "100pt", "80pt", "100pt"]
          stroke "1pt"
          fill "#2F5597"
          inset "5pt"

          label :name_header do
            text("Customer Name")
            style font_weight: "bold", color: "white"
          end

          label :health_header do
            text("Health Score")
            style font_weight: "bold", color: "white"
            align :right
          end

          label :tier_header do
            text("Tier")
            style font_weight: "bold", color: "white"
          end

          label :credit_limit_header do
            text("Credit Limit")
            style font_weight: "bold", color: "white"
            align :right
          end
        end
      end

      band :customer_detail do
        type :detail

        table :detail_table do
          columns ["150pt", "100pt", "80pt", "100pt"]
          stroke "0.5pt"
          inset "5pt"

          field :customer_name do
            source :name
          end

          field :health_score do
            source :customer_health_score
            align :right
            format :number
            decimal_places 2
          end

          field :tier do
            source :customer_tier
          end

          field :credit_limit do
            source :credit_limit
            align :right
            format :currency
            decimal_places 2
          end
        end
      end

      band :group_footer do
        type :group_footer
        group_level(1)

        table :group_footer_table do
          columns ["150pt", "100pt", "80pt", "100pt"]
          stroke "0.5pt"
          fill "#E8E8E8"
          inset "5pt"

          label :group_count do
            text("[group_customer_count]")
            style font_weight: "bold"
          end

          label :group_health_avg do
            text("[group_avg_health_score]")
            style font_weight: "bold"
            align :right
          end

          label :group_spacer do
            text("")
          end

          label :group_credit_total do
            text("[group_total_credit_limit]")
            style font_weight: "bold"
            align :right
          end
        end
      end

      band :summary do
        type :summary

        table :summary_table do
          columns ["150pt", "100pt", "80pt", "100pt"]
          stroke "1pt"
          fill "#2F5597"
          inset "5pt"

          label :total_customers do
            text("[customer_count]")
            style font_weight: "bold", color: "white"
          end

          label :summary_spacer1 do
            text("")
          end

          label :summary_spacer2 do
            text("")
          end

          label :total_value do
            text("[total_lifetime_value]")
            style font_weight: "bold", color: "white"
            align :right
          end
        end
      end
    end

    # Product Inventory Report - Profitability analytics
    report :product_inventory do
      title("Product Inventory Report")
      description "Inventory analysis with profitability metrics"
      driving_resource(AshReportsDemo.Product)

      # Scope expression to filter products based on parameters
      base_filter(fn params ->
        import Ash.Query

        AshReportsDemo.Product
        |> new()
        |> then(fn query ->
          # Filter by dataset_id for multi-dataset support
          case params[:dataset_id] do
            nil -> query
            dataset_id -> query |> filter(dataset_id == ^dataset_id)
          end
        end)
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
        |> Ash.Query.load(:margin_percentage)
      end)

      # Dataset parameter for multitenancy filtering
      parameter(:dataset_id, :string)

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

      # Title band with grid layout for centered, styled title
      band :title do
        type :title

        grid :title_grid do
          columns ["1fr"]
          align {:center, :horizon}
          inset "10pt"

          label :report_title do
            text("Product Inventory Report")
            style font_size: 24, font_weight: "bold", color: "blue"
          end
        end
      end

      # Column headers band with table layout
      band :column_header do
        type :column_header

        table :header_table do
          columns [2, 1, 1, 1]
          stroke "1pt"
          fill "blue"
          inset "5pt"

          label :product_name_header do
            text("Product Name")
            style font_weight: "bold", color: "white"
          end

          label :sku_header do
            text("SKU")
            style font_weight: "bold", color: "white"
          end

          label :price_header do
            text("Price")
            style font_weight: "bold", color: "white"
          end

          label :margin_header do
            text("Margin %")
            style font_weight: "bold", color: "white"
          end
        end
      end

      # Detail band with table layout for each data row
      band :product_detail do
        type :detail

        table :detail_table do
          columns [2, 1, 1, 1]
          stroke "0.5pt"
          inset "5pt"

          field :product_name do
            source :name
          end

          field :sku do
            source :sku
          end

          field :price do
            source :price
            format :currency
            decimal_places 2
          end

          field :margin do
            source :margin_percentage
            format :percent
            decimal_places 1
          end
        end
      end

      # Summary band with grid layout for metrics display
      band :inventory_summary do
        type :summary

        grid :summary_grid do
          columns 2
          rows 2
          gutter "10pt"
          align :center
          inset "10pt"
          fill "#e8e8e8"

          label :products_label do
            text("Total Products")
            style font_weight: "bold"
          end

          label :value_label do
            text("Inventory Value")
            style font_weight: "bold"
          end

          label :products_value do
            text("[total_products]")
            style font_size: 16
          end

          label :value_amount do
            text("$[total_inventory_value]")
            style font_size: 16
          end
        end
      end
    end

    # Invoice Details Report - Master-detail financial analysis
    report :invoice_details do
      title("Invoice Details Report")
      description "Comprehensive invoice analysis with payment performance"
      driving_resource(AshReportsDemo.Invoice)

      # Scope expression to filter invoices based on parameters
      base_filter(fn params ->
        import Ash.Query

        AshReportsDemo.Invoice
        |> new()
        |> then(fn query ->
          # Filter by dataset_id for multi-dataset support
          case params[:dataset_id] do
            nil -> query
            dataset_id -> query |> filter(dataset_id == ^dataset_id)
          end
        end)
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

      # Dataset parameter for multitenancy filtering
      parameter(:dataset_id, :string)

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
          position align: [:top, :center]
          style font_size: 24, color: "#2F5597", font_weight: "bold"
          padding bottom: "20pt"
        end
      end

      band :column_header do
        type :column_header

        table :header_table do
          columns ["100pt", "85pt", "80pt", "80pt"]
          stroke "1pt"
          fill "#2F5597"
          inset "5pt"

          label :invoice_number_header do
            text("Invoice #")
            style font_weight: "bold", color: "white"
          end

          label :date_header do
            text("Date")
            style font_weight: "bold", color: "white"
          end

          label :status_header do
            text("Status")
            style font_weight: "bold", color: "white"
          end

          label :total_header do
            text("Total")
            style font_weight: "bold", color: "white"
          end
        end
      end

      band :invoice_detail do
        type :detail

        table :detail_table do
          columns ["100pt", "85pt", "80pt", "80pt"]
          stroke "0.5pt"
          inset "5pt"

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
      base_filter(fn params ->
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
        |> then(fn query ->
          # Filter by dataset_id for multi-dataset support
          case params[:dataset_id] do
            nil -> query
            dataset_id -> query |> filter(dataset_id == ^dataset_id)
          end
        end)
        |> filter(date >= ^start_date and date <= ^end_date)
        |> filter(status in [:sent, :paid, :overdue])
      end)

      # Dataset parameter for multitenancy filtering
      parameter(:dataset_id, :string)

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
          position align: [:top, :center]
          style font_size: 24, color: "#2F5597", font_weight: "bold"
          padding bottom: "20pt"
        end
      end

      band :column_header do
        type :column_header

        table :header_table do
          columns ["120pt", "100pt", "80pt"]
          stroke "1pt"
          fill "#2F5597"
          inset "5pt"

          label :invoice_number_header do
            text("Invoice #")
            style font_weight: "bold", color: "white"
          end

          label :date_header do
            text("Date")
            style font_weight: "bold", color: "white"
          end

          label :total_header do
            text("Total")
            style font_weight: "bold", color: "white"
          end
        end
      end

      band :invoice_details do
        type :detail

        table :detail_table do
          columns ["120pt", "100pt", "80pt"]
          stroke "0.5pt"
          inset "5pt"

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
      end

      band :executive_summary do
        type :summary

        label :revenue_summary do
          text("Total Revenue: [total_revenue] across [invoice_count] transactions")
        end
      end
    end

    # Session Analytics Charts

    # 9. Session Activity Over Time - Line Chart
    line_chart :session_activity_timeline do
      driving_resource(AshReportsDemo.SessionMetrics)

      transform do
        filters(%{period_type: :hour})
        as_x(:period_start)
        as_y(:total_sessions)
        sort_by({:period_start, :asc})
      end

      config do
        width(600)
        height(300)
        title("Session Activity Timeline")
        colours(["4472C4"])
      end
    end

    # 10. Bounce Rate Analysis - Pie Chart
    pie_chart :bounce_rate_analysis do
      driving_resource(AshReportsDemo.SessionSnapshot)

      transform do
        group_by(:is_bounce)
        aggregates([{:count, nil, :count}])
        as_category(:group_key)
        as_value(:count)
      end

      config do
        width(400)
        height(300)
        title("Session Engagement")
        colours(["10B981", "EF4444"])
      end
    end

    # 11. Page Views Distribution - Bar Chart
    bar_chart :page_views_distribution do
      driving_resource(AshReportsDemo.SessionSnapshot)

      transform do
        group_by(:page_views)
        aggregates([{:count, nil, :count}])
        as_category(:group_key)
        as_value(:count)
        sort_by({:group_key, :asc})
        limit 10
      end

      config do
        width(500)
        height(300)
        title("Page Views per Session")
        colours(["2F5597"])
      end
    end

    # Telemetry Performance Charts

    # 12. Chart Data Query Performance Over Time - Line Chart
    line_chart :chart_query_performance_timeline do
      driving_resource(AshReportsDemo.Resources.TelemetryEvent)

      transform do
        filters(%{event_type: :chart_data_query, success: true})
        as_x(:inserted_at)
        as_y(:duration_microseconds)
        sort_by({:inserted_at, :asc})
        limit 50
      end

      config do
        width(700)
        height(350)
        title("Chart Data Query Performance Over Time")
        stroke_width("2")
        colours(["3B82F6"])
        axis_label_rotation(:auto)
      end
    end

    # 13. Chart Generation Performance Over Time - Line Chart
    line_chart :chart_generation_performance_timeline do
      driving_resource(AshReportsDemo.Resources.TelemetryEvent)

      transform do
        filters(%{event_type: :chart_generate, success: true})
        as_x(:inserted_at)
        as_y(:duration_microseconds)
        sort_by({:inserted_at, :asc})
        limit 50
      end

      config do
        width(700)
        height(350)
        title("Chart Generation Performance Over Time")
        stroke_width("2")
        colours(["10B981"])
        axis_label_rotation(:auto)
      end
    end

    # 14. Request Performance Distribution - Bar Chart
    bar_chart :request_performance_distribution do
      driving_resource(AshReportsDemo.Resources.TelemetryEvent)

      transform do
        filters(%{success: true})
        group_by(:event_type)
        aggregates([{:avg, :duration_microseconds, :avg_duration}])
        as_category(:group_key)
        as_value(:avg_duration)
        sort_by({:avg_duration, :desc})
      end

      config do
        width(600)
        height(400)
        title("Average Performance by Operation Type")
        type(:simple)
        orientation(:vertical)
        data_labels(true)
        colours(["8B5CF6", "EC4899", "F59E0B", "10B981"])
      end
    end

    # 15. Performance Trends Comparison - Area Chart
    area_chart :performance_trends_comparison do
      driving_resource(AshReportsDemo.Resources.TelemetryEvent)

      transform do
        filters(%{success: true})
        group_by({:inserted_at, :minute})
        aggregates([{:avg, :duration_microseconds, :avg_duration}])
        as_x(:group_key)
        as_y(:avg_duration)
        sort_by({:group_key, :asc})
        limit 30
      end

      config do
        width(800)
        height(400)
        title("Performance Trends (5-minute intervals)")
        mode(:simple)
        opacity(0.7)
        colours(["059669"])
      end
    end
  end

  authorization do
    # Phase 7.4: Will be implemented with policy-based authorization
    authorize :when_requested
  end
end
