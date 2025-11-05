defmodule AshReportsDemoWeb.DataSummaryLive do
  use AshReportsDemoWeb, :live_view

  alias AshReportsDemoWeb.Components.{DataSummaryComponent, DataViewModal}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Data Summary")
     |> assign(:show_data_modal, false)
     |> assign(:modal_title, "")
     |> assign(:csv_data, "")
     |> assign(:current_data_type, nil)}
  end

  @impl true
  def handle_info({:show_data_modal, title, csv_data, data_type}, socket) do
    {:noreply,
     socket
     |> assign(:show_data_modal, true)
     |> assign(:modal_title, title)
     |> assign(:csv_data, csv_data)
     |> assign(:current_data_type, data_type)
     |> push_event("show-modal", %{id: "data-view-modal"})}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_data_modal, false)
     |> assign(:csv_data, "")
     |> assign(:current_data_type, nil)
     |> push_event("hide-modal", %{id: "data-view-modal"})}
  end

  @impl true
  def handle_event("copy_csv", _params, socket) do
    {:noreply,
     socket
     |> push_event("copy-to-clipboard", %{text: socket.assigns.csv_data})}
  end

  @impl true
  def handle_event("download_csv", _params, socket) do
    filename = "#{socket.assigns.current_data_type}_#{Date.utc_today()}.csv"

    {:noreply,
     socket
     |> push_event("download-csv", %{csv: socket.assigns.csv_data, filename: filename})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Data Summary
      <:subtitle>
        View and manage generated sample data for the reporting system
      </:subtitle>
    </.header>

    <div class="mt-8">
      <.live_component
        module={DataSummaryComponent}
        id="data-summary"
      />
    </div>

    <DataViewModal.data_view_modal
      id="data-view-modal"
      show={@show_data_modal}
      title={@modal_title}
      csv_data={@csv_data}
      on_cancel={JS.push("close_modal")}
    />
    """
  end
end
