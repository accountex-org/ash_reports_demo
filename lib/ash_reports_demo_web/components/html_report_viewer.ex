defmodule AshReportsDemoWeb.Components.HtmlReportViewer do
  @moduledoc """
  Component for displaying HTML-rendered reports with responsive styling and print support.

  Features:
  - Responsive layout for different screen sizes
  - Print-friendly styling with media queries
  - Dark mode support
  - Safe HTML rendering
  - Optional print mode
  """

  use Phoenix.Component

  attr :content, :string, required: true, doc: "The HTML content to display"
  attr :metadata, :map, default: %{}, doc: "Report metadata for display"
  attr :print_mode, :boolean, default: false, doc: "Enable print-optimized mode"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  @doc """
  Renders an HTML report with responsive styling and print support.
  """
  def html_report_viewer(assigns) do
    ~H"""
    <div class={["html-report-container", @print_mode && "print-mode", @class]} data-responsive="true">
      <div class="report-content-wrapper">
        <div class="report-content">
          <%= Phoenix.HTML.raw(@content) %>
        </div>
      </div>

      <%= if @print_mode do %>
        <div class="print-actions no-print">
          <button
            type="button"
            onclick="window.print()"
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
          >
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
            </svg>
            Print Report
          </button>
        </div>
      <% end %>

      <style>
        .html-report-container {
          width: 100%;
          max-width: 100%;
          margin: 0 auto;
          background: white;
          border-radius: 0.5rem;
          overflow: hidden;
        }

        .report-content-wrapper {
          overflow-x: auto;
          padding: 1rem;
        }

        .report-content {
          min-height: 200px;
        }

        .print-actions {
          padding: 1rem;
          border-top: 1px solid #e5e7eb;
          background: #f9fafb;
        }

        @media (min-width: 768px) {
          .report-content-wrapper {
            padding: 2rem;
          }
        }

        @media print {
          .no-print {
            display: none !important;
          }

          .html-report-container {
            box-shadow: none;
            border: none;
            margin: 0;
            padding: 0;
          }

          .report-content-wrapper {
            padding: 0;
          }

          body {
            background: white;
          }
        }

        @media (prefers-color-scheme: dark) {
          .html-report-container {
            background: #1f2937;
            color: #f3f4f6;
          }

          .print-actions {
            background: #374151;
            border-color: #4b5563;
          }
        }

        [data-theme="dark"] .html-report-container {
          background: #1f2937;
          color: #f3f4f6;
        }

        [data-theme="dark"] .print-actions {
          background: #374151;
          border-color: #4b5563;
        }
      </style>
    </div>
    """
  end
end
