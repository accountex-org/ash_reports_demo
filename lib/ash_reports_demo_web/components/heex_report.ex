defmodule AshReportsDemoWeb.Components.HeexReport do
  @moduledoc """
  Component for rendering HEEX-formatted reports as LiveView components.

  Supports interactive features like filtering and sorting.
  """

  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:filter_term, "")
     |> assign(:sort_by, nil)
     |> assign(:sort_order, :asc)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:interactive, fn -> false end)
     |> assign_new(:show_controls, fn -> false end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="heex-report-container">
      <%= if @show_controls do %>
        <div class="heex-controls mb-4 flex gap-4">
          <div class="flex-1">
            <input
              type="search"
              placeholder="Filter results..."
              value={@filter_term}
              phx-change="filter"
              phx-debounce="300"
              phx-target={@myself}
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            />
          </div>
          <div>
            <select
              phx-change="sort"
              phx-target={@myself}
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            >
              <option value="">Sort by...</option>
              <option value="name">Name</option>
              <option value="date">Date</option>
              <option value="amount">Amount</option>
            </select>
          </div>
        </div>
      <% end %>

      <div class="heex-report-content">
        <%= render_heex_content(assigns) %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("filter", %{"value" => term}, socket) do
    {:noreply, assign(socket, :filter_term, term)}
  end

  @impl true
  def handle_event("sort", %{"value" => sort_by}, socket) do
    new_order =
      if socket.assigns.sort_by == sort_by && socket.assigns.sort_order == :asc do
        :desc
      else
        :asc
      end

    {:noreply,
     socket
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, new_order)}
  end

  defp render_heex_content(%{content: content} = assigns) when is_binary(content) do
    assigns = Map.put(assigns, :content, content)

    ~H"""
    <div class="heex-content-wrapper bg-white rounded-lg shadow p-6">
      <pre class="whitespace-pre-wrap font-mono text-sm"><%= @content %></pre>
    </div>
    """
  end

  defp render_heex_content(assigns) do
    ~H"""
    <div class="heex-content-wrapper bg-white rounded-lg shadow p-6">
      <p class="text-gray-500 italic">No HEEX content available</p>
    </div>
    """
  end
end
