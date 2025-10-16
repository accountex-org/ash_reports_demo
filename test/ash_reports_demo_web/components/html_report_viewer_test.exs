defmodule AshReportsDemoWeb.Components.HtmlReportViewerTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias AshReportsDemoWeb.Components.HtmlReportViewer

  describe "html_report_viewer/1" do
    test "renders HTML content" do
      assigns = %{
        content: "<div>Test Report</div>",
        metadata: %{},
        print_mode: false,
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <HtmlReportViewer.html_report_viewer
          content={@content}
          metadata={@metadata}
          print_mode={@print_mode}
          class={@class}
        />
        """)

      assert html =~ "html-report-container"
      assert html =~ "Test Report"
    end

    test "renders with print mode enabled" do
      assigns = %{
        content: "<div>Test Report</div>",
        metadata: %{},
        print_mode: true,
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <HtmlReportViewer.html_report_viewer
          content={@content}
          metadata={@metadata}
          print_mode={@print_mode}
        />
        """)

      assert html =~ "print-mode"
      assert html =~ "Print Report"
      assert html =~ "window.print()"
    end

    test "applies custom CSS classes" do
      assigns = %{
        content: "<div>Test</div>",
        metadata: %{},
        print_mode: false,
        class: "custom-class"
      }

      html =
        rendered_to_string(~H"""
        <HtmlReportViewer.html_report_viewer
          content={@content}
          metadata={@metadata}
          class={@class}
        />
        """)

      assert html =~ "custom-class"
    end

    test "includes responsive styling" do
      assigns = %{
        content: "<div>Test</div>",
        metadata: %{},
        print_mode: false,
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <HtmlReportViewer.html_report_viewer
          content={@content}
          metadata={@metadata}
        />
        """)

      assert html =~ "data-responsive"
      assert html =~ "@media"
    end

    test "includes print CSS" do
      assigns = %{
        content: "<div>Test</div>",
        metadata: %{},
        print_mode: false,
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <HtmlReportViewer.html_report_viewer
          content={@content}
          metadata={@metadata}
        />
        """)

      assert html =~ "@media print"
      assert html =~ "no-print"
    end

    test "includes dark mode support" do
      assigns = %{
        content: "<div>Test</div>",
        metadata: %{},
        print_mode: false,
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <HtmlReportViewer.html_report_viewer
          content={@content}
          metadata={@metadata}
        />
        """)

      assert html =~ "prefers-color-scheme: dark"
      assert html =~ ~s([data-theme="dark"])
    end

    test "renders empty content safely" do
      assigns = %{
        content: "",
        metadata: %{},
        print_mode: false,
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <HtmlReportViewer.html_report_viewer
          content={@content}
          metadata={@metadata}
        />
        """)

      assert html =~ "html-report-container"
    end
  end
end
