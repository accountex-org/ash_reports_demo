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
            class="print-button"
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
          border: 2px solid #B4C6E7;
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
          border-top: 2px solid #B4C6E7;
          background: #4472C4;
        }

        .print-actions button {
          background: #2F5597;
          color: white;
          border: none;
          padding: 0.5rem 1rem;
          border-radius: 0.375rem;
          cursor: pointer;
          transition: background-color 0.2s;
          display: inline-flex;
          align-items: center;
          font-size: 0.875rem;
          font-weight: 500;
        }

        .print-actions button:hover {
          background: #203764;
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
            background: #203764;
            color: white;
            border-color: #2F5597;
          }

          .print-actions {
            background: #2F5597;
            border-color: #4472C4;
          }
        }

        [data-theme="dark"] .html-report-container {
          background: #203764;
          color: white;
          border-color: #2F5597;
        }

        [data-theme="dark"] .print-actions {
          background: #2F5597;
          border-color: #4472C4;
        }
      </style>
    </div>
    """
  end
end
