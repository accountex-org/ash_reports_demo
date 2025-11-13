defmodule AshReportsDemoWeb.Components.DataViewModal do
  @moduledoc """
  Modal component for viewing and downloading CSV data.
  """
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :title, :string, required: true
  attr :csv_data, :string, default: ""
  attr :on_cancel, JS, default: %JS{}

  def data_view_modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-zinc-900/90 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="w-full max-w-4xl">
            <div
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="relative hidden rounded-2xl bg-white shadow-lg shadow-zinc-700/10 ring-1 ring-zinc-700/10 transition"
            >
              <div class="px-6 py-5 border-b border-gray-200">
                <div class="flex items-center justify-between">
                  <div>
                    <h3 id={"#{@id}-title"} class="text-lg font-semibold text-gray-900">
                      {@title}
                    </h3>
                    <p id={"#{@id}-description"} class="mt-1 text-sm text-gray-500">
                      CSV formatted data - Copy or download the data below
                    </p>
                  </div>
                  <button
                    phx-click={JS.exec("data-cancel", to: "##{@id}")}
                    type="button"
                    class="rounded-md text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-[#4472C4] focus:ring-offset-2"
                    aria-label="Close"
                  >
                    <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              </div>

              <div class="px-6 py-4">
                <div class="space-y-4">
                  <div class="flex items-center justify-between">
                    <span class="text-sm text-gray-700">
                      <%= count_rows(@csv_data) %> records
                    </span>
                    <div class="flex gap-2">
                      <button
                        type="button"
                        phx-click="copy_csv"
                        class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#4472C4]"
                      >
                        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                        </svg>
                        Copy CSV
                      </button>
                      <button
                        type="button"
                        phx-click="download_csv"
                        class="inline-flex items-center px-3 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-[#4472C4] hover:bg-[#2F5597] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#4472C4]"
                      >
                        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                        Download CSV
                      </button>
                    </div>
                  </div>

                  <div class="bg-gray-50 rounded-lg border border-gray-200 overflow-hidden">
                    <pre
                      id={"#{@id}-csv-content"}
                      class="overflow-auto p-4 text-xs font-mono text-gray-800 max-h-96"
                      style="tab-size: 4;"
                    ><%= @csv_data %></pre>
                  </div>
                </div>
              </div>

              <div class="px-6 py-4 bg-gray-50 border-t border-gray-200 rounded-b-2xl flex justify-end">
                <button
                  type="button"
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#4472C4]"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp count_rows(csv_data) when is_binary(csv_data) do
    csv_data
    |> String.split("\n", trim: true)
    |> length()
    |> Kernel.-(1)
    |> max(0)
  end

  defp count_rows(_), do: 0

  defp show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      time: 300,
      display: "block",
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
  end

  defp hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
  end
end
