defmodule AshReportsDemoWeb.Components.DataSummaryComponent do
  @moduledoc """
  LiveComponent for displaying data summary statistics and CSV export functionality.
  """
  use AshReportsDemoWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:show_data_modal, false)
     |> assign(:modal_title, "")
     |> assign(:csv_data, "")
     |> assign(:current_data_type, nil)
     |> assign(:available_datasets, [])
     |> assign(:loading_dataset, false)}
  end

  @impl true
  def update(%{loading_complete: true, dataset_size: dataset_size, data_summary: new_summary}, socket) do
    require Logger
    Logger.info("update/2 callback: loading_complete received for dataset #{dataset_size}")

    {:ok,
     socket
     |> assign(:dataset_size, dataset_size)
     |> assign(:data_summary, new_summary)
     |> assign(:loading_dataset, false)
     |> put_flash(:info, "Switched to #{dataset_size} dataset successfully!")}
  end

  def update(%{loading_error: message}, socket) do
    require Logger
    Logger.error("update/2 callback: loading_error received: #{message}")

    {:ok,
     socket
     |> assign(:loading_dataset, false)
     |> put_flash(:error, "Failed to switch dataset: #{message}")}
  end

  def update(assigns, socket) do
    available_datasets = AshReportsDemo.DataGenerator.get_available_datasets()
    current_dataset = AshReportsDemo.DataGenerator.get_current_dataset()

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:data_summary, fn -> load_data_summary() end)
     |> assign_new(:dataset_size, fn -> current_dataset end)
     |> assign(:available_datasets, available_datasets)}
  end

  @impl true
  def handle_event("noop", _params, socket) do
    # Prevent form submission
    {:noreply, socket}
  end

  @impl true
  def handle_event("view_data", %{"type" => data_type}, socket) do
    {title, csv_data} = generate_csv_data(data_type)

    send(self(), {:show_data_modal, title, csv_data, data_type})

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_dataset_size", %{"size" => size}, socket) do
    dataset_size = String.to_existing_atom(size)
    require Logger

    Logger.info("Changing dataset size to: #{dataset_size}")

    # Set loading state immediately and spawn background task
    component_id = socket.assigns.id
    # Capture the parent LiveView PID for send_update from Task
    lv_pid = self()
    Logger.info("Component ID: #{inspect(component_id)}, LiveView PID: #{inspect(lv_pid)}")

    Task.start(fn ->
      Logger.info("Task started for dataset loading: #{dataset_size}")

      case AshReportsDemo.DataGenerator.generate_sample_data(dataset_size) do
        :ok ->
          new_summary = AshReportsDemo.DataGenerator.get_current_dataset_counts()
          Logger.info("Loaded new data summary: #{inspect(new_summary)}")
          Logger.info("Sending update to component: #{component_id}")

          # Use send_update/3 with explicit target PID since we're in a separate process
          Phoenix.LiveView.send_update(lv_pid, __MODULE__,
            id: component_id,
            loading_complete: true,
            dataset_size: dataset_size,
            data_summary: new_summary
          )

          Logger.info("send_update called successfully")

        {:error, message} ->
          Logger.error("Failed to switch dataset: #{message}")

          Phoenix.LiveView.send_update(lv_pid, __MODULE__,
            id: component_id,
            loading_error: message
          )
      end
    end)

    {:noreply, socket |> assign(:loading_dataset, true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="data-summary-component" class="relative">
      <!-- Loading Overlay -->
      <%= if @loading_dataset do %>
        <div class="absolute inset-0 bg-gray-900/50 backdrop-blur-sm rounded-lg z-10 flex items-center justify-center">
          <div class="bg-white rounded-lg p-6 shadow-xl flex flex-col items-center gap-4">
            <svg class="animate-spin h-12 w-12 text-[#4472C4]" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <div class="text-center">
              <p class="text-lg font-semibold text-gray-900">Loading Dataset</p>
              <p class="text-sm text-gray-600 mt-1">Please wait...</p>
            </div>
          </div>
        </div>
      <% end %>

      <div class="bg-gradient-to-br from-[#2F5597] to-[#4472C4] rounded-lg shadow-lg p-6">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h2 class="text-lg font-semibold text-white">Pre-Generated Data Summary</h2>
            <p class="text-sm text-[#B4C6E7] mt-1">Multiple dataset sizes available - switch instantly</p>
          </div>
          <div class="flex items-center gap-3">
            <form phx-change="change_dataset_size" phx-submit="noop" phx-target={@myself} class="relative">
              <select
                name="size"
                disabled={@loading_dataset}
                class={"appearance-none bg-white text-gray-700 border border-gray-200 rounded-lg pl-4 pr-10 py-2 focus:outline-none focus:ring-2 focus:ring-white/50 font-medium #{if @loading_dataset, do: "opacity-50 cursor-not-allowed", else: ""}"}
              >
                <option value="small" selected={@dataset_size == :small} disabled={:small not in @available_datasets}>
                  Small Dataset
                </option>
                <option value="medium" selected={@dataset_size == :medium} disabled={:medium not in @available_datasets}>
                  Medium Dataset
                </option>
                <option value="large" selected={@dataset_size == :large} disabled={:large not in @available_datasets}>
                  Large Dataset
                </option>
                <option value="huge" selected={@dataset_size == :huge} disabled={:huge not in @available_datasets}>
                  Huge Dataset
                </option>
              </select>
              <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
                <%= if @loading_dataset do %>
                  <svg class="animate-spin h-4 w-4 text-gray-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                <% else %>
                  <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                <% end %>
              </div>
            </form>
          </div>
        </div>
        
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <button
            type="button"
            phx-click="view_data"
            phx-value-type="customer_types"
            phx-target={@myself}
            class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20 hover:bg-white/20 transition-colors cursor-pointer text-left"
          >
            <div class="flex items-center justify-between">
              <div>
                <p class="text-[#B4C6E7] text-sm font-medium">Customer Types</p>
                <p class="text-3xl font-bold text-white mt-1"><%= @data_summary.customer_types %></p>
              </div>
              <div class="bg-white/20 rounded-full p-3">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
                </svg>
              </div>
            </div>
          </button>

          <button
            type="button"
            phx-click="view_data"
            phx-value-type="product_categories"
            phx-target={@myself}
            class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20 hover:bg-white/20 transition-colors cursor-pointer text-left"
          >
            <div class="flex items-center justify-between">
              <div>
                <p class="text-[#B4C6E7] text-sm font-medium">Product Categories</p>
                <p class="text-3xl font-bold text-white mt-1"><%= @data_summary.product_categories %></p>
              </div>
              <div class="bg-white/20 rounded-full p-3">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                </svg>
              </div>
            </div>
          </button>
          
          <button
            type="button"
            phx-click="view_data"
            phx-value-type="customers"
            phx-target={@myself}
            class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20 hover:bg-white/20 transition-colors cursor-pointer text-left"
          >
            <div class="flex items-center justify-between">
              <div>
                <p class="text-[#B4C6E7] text-sm font-medium">Customers</p>
                <p class="text-3xl font-bold text-white mt-1"><%= @data_summary.customers %></p>
              </div>
              <div class="bg-white/20 rounded-full p-3">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
              </div>
            </div>
          </button>

          <button
            type="button"
            phx-click="view_data"
            phx-value-type="addresses"
            phx-target={@myself}
            class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20 hover:bg-white/20 transition-colors cursor-pointer text-left"
          >
            <div class="flex items-center justify-between">
              <div>
                <p class="text-[#B4C6E7] text-sm font-medium">Addresses</p>
                <p class="text-3xl font-bold text-white mt-1"><%= @data_summary.addresses %></p>
              </div>
              <div class="bg-white/20 rounded-full p-3">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
              </div>
            </div>
          </button>
          
          <button
            type="button"
            phx-click="view_data"
            phx-value-type="products"
            phx-target={@myself}
            class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20 hover:bg-white/20 transition-colors cursor-pointer text-left"
          >
            <div class="flex items-center justify-between">
              <div>
                <p class="text-[#B4C6E7] text-sm font-medium">Products</p>
                <p class="text-3xl font-bold text-white mt-1"><%= @data_summary.products %></p>
              </div>
              <div class="bg-white/20 rounded-full p-3">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                </svg>
              </div>
            </div>
          </button>

          <button
            type="button"
            phx-click="view_data"
            phx-value-type="inventory"
            phx-target={@myself}
            class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20 hover:bg-white/20 transition-colors cursor-pointer text-left"
          >
            <div class="flex items-center justify-between">
              <div>
                <p class="text-[#B4C6E7] text-sm font-medium">Inventory</p>
                <p class="text-3xl font-bold text-white mt-1"><%= @data_summary.inventory %></p>
              </div>
              <div class="bg-white/20 rounded-full p-3">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4" />
                </svg>
              </div>
            </div>
          </button>
          
          <button
            type="button"
            phx-click="view_data"
            phx-value-type="invoices"
            phx-target={@myself}
            class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20 hover:bg-white/20 transition-colors cursor-pointer text-left"
          >
            <div class="flex items-center justify-between">
              <div>
                <p class="text-[#B4C6E7] text-sm font-medium">Invoices</p>
                <p class="text-3xl font-bold text-white mt-1"><%= @data_summary.invoices %></p>
              </div>
              <div class="bg-white/20 rounded-full p-3">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
              </div>
            </div>
          </button>
          
          <button
            type="button"
            phx-click="view_data"
            phx-value-type="line_items"
            phx-target={@myself}
            class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20 hover:bg-white/20 transition-colors cursor-pointer text-left"
          >
            <div class="flex items-center justify-between">
              <div>
                <p class="text-[#B4C6E7] text-sm font-medium">Line Items</p>
                <p class="text-3xl font-bold text-white mt-1"><%= @data_summary.line_items %></p>
              </div>
              <div class="bg-white/20 rounded-full p-3">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
                </svg>
              </div>
            </div>
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp load_data_summary do
    # Get pre-calculated counts from DataGenerator (no ETS/Ash queries needed!)
    AshReportsDemo.DataGenerator.get_current_dataset_counts()
  end

  defp generate_csv_data(data_type) do
    case data_type do
      "customers" -> generate_customers_csv()
      "products" -> generate_products_csv()
      "invoices" -> generate_invoices_csv()
      "line_items" -> generate_line_items_csv()
      "customer_types" -> generate_customer_types_csv()
      "product_categories" -> generate_product_categories_csv()
      "addresses" -> generate_addresses_csv()
      "inventory" -> generate_inventory_csv()
      _ -> {"Unknown Data", ""}
    end
  end

  defp generate_customers_csv do
    alias AshReportsDemo.Customer

    customers =
      Customer
      |> Ash.read!()
      |> Enum.sort_by(& &1.name)

    headers = "Name,Email,Phone,Status,Credit Limit,Created At\n"

    rows =
      Enum.map_join(customers, "\n", fn customer ->
        [
          escape_csv_field(customer.name),
          escape_csv_field(customer.email),
          escape_csv_field(customer.phone || ""),
          customer.status,
          customer.credit_limit,
          DateTime.to_date(customer.created_at)
        ]
        |> Enum.join(",")
      end)

    csv = headers <> rows
    {"Customers Data", csv}
  end

  defp generate_products_csv do
    alias AshReportsDemo.Product

    products =
      Product
      |> Ash.read!()
      |> Enum.sort_by(& &1.name)

    headers = "Name,SKU,Price,Cost,Weight,Active,Created At\n"

    rows =
      Enum.map_join(products, "\n", fn product ->
        [
          escape_csv_field(product.name),
          escape_csv_field(product.sku),
          product.price,
          product.cost,
          product.weight || "0",
          product.active,
          DateTime.to_date(product.created_at)
        ]
        |> Enum.join(",")
      end)

    csv = headers <> rows
    {"Products Data", csv}
  end

  defp generate_invoices_csv do
    alias AshReportsDemo.Invoice

    invoices =
      Invoice
      |> Ash.read!(load: [:customer])
      |> Enum.sort_by(& &1.invoice_number)

    headers = "Invoice Number,Customer,Date,Due Date,Status,Subtotal,Tax Amount,Total\n"

    rows =
      invoices
      |> Enum.map(fn invoice ->
        customer_name =
          if invoice.customer do
            invoice.customer.name
          else
            "Unknown"
          end

        [
          escape_csv_field(invoice.invoice_number),
          escape_csv_field(customer_name),
          invoice.date,
          invoice.due_date || "",
          invoice.status,
          invoice.subtotal,
          invoice.tax_amount,
          invoice.total
        ]
        |> Enum.join(",")
      end)
      |> Enum.join("\n")

    csv = headers <> rows
    {"Invoices Data", csv}
  end

  defp generate_line_items_csv do
    alias AshReportsDemo.InvoiceLineItem

    line_items =
      InvoiceLineItem
      |> Ash.read!(load: [invoice: :customer, product: []])

    headers = "Invoice Number,Customer,Product,Quantity,Unit Price,Discount %,Line Total\n"

    rows =
      line_items
      |> Enum.map(fn item ->
        invoice_number =
          if item.invoice do
            item.invoice.invoice_number
          else
            "Unknown"
          end

        customer_name =
          if item.invoice && item.invoice.customer do
            item.invoice.customer.name
          else
            "Unknown"
          end

        product_name =
          if item.product do
            item.product.name
          else
            "Unknown"
          end

        [
          escape_csv_field(invoice_number),
          escape_csv_field(customer_name),
          escape_csv_field(product_name),
          item.quantity,
          item.unit_price,
          item.discount_percentage || "0",
          item.line_total
        ]
        |> Enum.join(",")
      end)
      |> Enum.join("\n")

    csv = headers <> rows
    {"Line Items Data", csv}
  end

  defp generate_customer_types_csv do
    alias AshReportsDemo.CustomerType

    customer_types =
      CustomerType
      |> Ash.read!()
      |> Enum.sort_by(& &1.priority_level)

    headers = "Name,Description,Discount %,Priority Level,Active\n"

    rows =
      customer_types
      |> Enum.map(fn type ->
        [
          escape_csv_field(type.name),
          escape_csv_field(type.description || ""),
          type.discount_percentage,
          type.priority_level,
          type.active
        ]
        |> Enum.join(",")
      end)
      |> Enum.join("\n")

    csv = headers <> rows
    {"Customer Types Data", csv}
  end

  defp generate_product_categories_csv do
    alias AshReportsDemo.ProductCategory

    categories =
      ProductCategory
      |> Ash.read!()
      |> Enum.sort_by(& &1.sort_order)

    headers = "Name,Description,Sort Order,Active\n"

    rows =
      categories
      |> Enum.map(fn category ->
        [
          escape_csv_field(category.name),
          escape_csv_field(category.description || ""),
          category.sort_order,
          category.active
        ]
        |> Enum.join(",")
      end)
      |> Enum.join("\n")

    csv = headers <> rows
    {"Product Categories Data", csv}
  end

  defp generate_addresses_csv do
    alias AshReportsDemo.CustomerAddress

    addresses =
      CustomerAddress
      |> Ash.read!(load: [:customer])
      |> Enum.sort_by(fn addr -> {addr.customer && addr.customer.name, addr.primary} end, :desc)

    headers = "Customer,Type,Street,City,State,Postal Code,Country,Primary\n"

    rows =
      addresses
      |> Enum.map(fn address ->
        customer_name =
          if address.customer do
            address.customer.name
          else
            "Unknown"
          end

        [
          escape_csv_field(customer_name),
          address.address_type,
          escape_csv_field(address.street),
          escape_csv_field(address.city),
          escape_csv_field(address.state),
          escape_csv_field(address.postal_code),
          escape_csv_field(address.country),
          address.primary
        ]
        |> Enum.join(",")
      end)
      |> Enum.join("\n")

    csv = headers <> rows
    {"Customer Addresses Data", csv}
  end

  defp generate_inventory_csv do
    alias AshReportsDemo.Inventory

    inventory =
      Inventory
      |> Ash.read!(load: [:product])
      |> Enum.sort_by(fn inv -> inv.product && inv.product.name end)

    headers =
      "Product,Current Stock,Reserved Stock,Available,Reorder Point,Reorder Qty,Location,Last Received\n"

    rows =
      inventory
      |> Enum.map(fn inv ->
        product_name =
          if inv.product do
            inv.product.name
          else
            "Unknown"
          end

        available = inv.current_stock - (inv.reserved_stock || 0)

        [
          escape_csv_field(product_name),
          inv.current_stock,
          inv.reserved_stock || "0",
          available,
          inv.reorder_point,
          inv.reorder_quantity,
          escape_csv_field(inv.location || ""),
          inv.last_received_date || ""
        ]
        |> Enum.join(",")
      end)
      |> Enum.join("\n")

    csv = headers <> rows
    {"Inventory Data", csv}
  end

  defp escape_csv_field(nil), do: ""

  defp escape_csv_field(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      ~s("#{String.replace(value, "\"", "\"\"")}")
    else
      value
    end
  end

  defp escape_csv_field(value), do: to_string(value)
end
