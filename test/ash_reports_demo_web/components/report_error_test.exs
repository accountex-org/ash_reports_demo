defmodule AshReportsDemoWeb.Components.ReportErrorTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias AshReportsDemoWeb.Components.ReportError

  describe "report_error/1 component" do
    test "renders error with all required information" do
      assigns = %{
        error: %{
          stage: :data_loading,
          reason: :invalid_parameters,
          user_message: "Failed to load report data",
          suggested_action: "Check your parameters",
          technical_details: "Error details here"
        },
        retry_event: nil,
        show_technical_details: false,
        max_retries: 3,
        retry_count: 0
      }

      html =
        rendered_to_string(~H"""
        <ReportError.report_error {assigns} />
        """)

      assert html =~ "Report Generation Failed"
      assert html =~ "Failed to load report data"
      assert html =~ "Check your parameters"
      assert html =~ "Data Loading"
    end

    test "displays stage information correctly" do
      assigns = %{
        error: %{
          stage: :rendering,
          reason: :template_error,
          user_message: "Rendering failed",
          suggested_action: "Try a different format"
        },
        retry_event: nil,
        show_technical_details: false,
        max_retries: 3,
        retry_count: 0
      }

      html =
        rendered_to_string(~H"""
        <ReportError.report_error {assigns} />
        """)

      assert html =~ "Rendering"
    end

    test "shows technical details when enabled" do
      assigns = %{
        error: %{
          stage: :data_loading,
          reason: :error,
          user_message: "Error occurred",
          suggested_action: "Try again",
          technical_details: "Stack trace: line 42"
        },
        retry_event: nil,
        show_technical_details: true,
        max_retries: 3,
        retry_count: 0
      }

      html =
        rendered_to_string(~H"""
        <ReportError.report_error {assigns} />
        """)

      assert html =~ "Technical Details"
      assert html =~ "Stack trace: line 42"
    end

    test "renders retry button when event provided and retries available" do
      assigns = %{
        error: %{
          stage: :data_loading,
          reason: :error,
          user_message: "Error",
          suggested_action: "Retry"
        },
        retry_event: "retry_report",
        show_technical_details: false,
        max_retries: 3,
        retry_count: 0
      }

      html =
        rendered_to_string(~H"""
        <ReportError.report_error {assigns} />
        """)

      assert html =~ "Retry Report"
    end

    test "shows retry count when retries have been attempted" do
      assigns = %{
        error: %{
          stage: :data_loading,
          reason: :error,
          user_message: "Error",
          suggested_action: "Retry"
        },
        retry_event: "retry_report",
        show_technical_details: false,
        max_retries: 3,
        retry_count: 1
      }

      html =
        rendered_to_string(~H"""
        <ReportError.report_error {assigns} />
        """)

      assert html =~ "Attempt 2/3" or html =~ "Retry"
    end

    test "shows max retries reached message when exhausted" do
      assigns = %{
        error: %{
          stage: :data_loading,
          reason: :error,
          user_message: "Error",
          suggested_action: "Retry"
        },
        retry_event: "retry_report",
        show_technical_details: false,
        max_retries: 3,
        retry_count: 3
      }

      html =
        rendered_to_string(~H"""
        <ReportError.report_error {assigns} />
        """)

      assert html =~ "Maximum retry attempts reached" or html =~ "retry"
    end

    test "always shows edit parameters button" do
      assigns = %{
        error: %{
          stage: :data_loading,
          reason: :error,
          user_message: "Error",
          suggested_action: "Fix"
        },
        retry_event: nil,
        show_technical_details: false,
        max_retries: 3,
        retry_count: 0
      }

      html =
        rendered_to_string(~H"""
        <ReportError.report_error {assigns} />
        """)

      assert html =~ "Edit Parameters"
    end
  end

  describe "pipeline_diagram/1 component" do
    test "renders pipeline stages" do
      assigns = %{stage: :data_loading}

      html =
        rendered_to_string(~H"""
        <ReportError.pipeline_diagram {assigns} />
        """)

      assert html =~ "Data Loading"
      assert html =~ "Context Building"
      assert html =~ "Rendering"
    end

    test "highlights failed stage" do
      assigns = %{stage: :context_building}

      html =
        rendered_to_string(~H"""
        <ReportError.pipeline_diagram {assigns} />
        """)

      # Should contain all three stages
      assert html =~ "Data Loading"
      assert html =~ "Context Building"
      assert html =~ "Rendering"

      # Context building should be styled differently (contains red classes)
      assert html =~ "red"
    end

    test "shows completed stages before failure" do
      assigns = %{stage: :rendering}

      html =
        rendered_to_string(~H"""
        <ReportError.pipeline_diagram {assigns} />
        """)

      # All stages present
      assert html =~ "Data Loading"
      assert html =~ "Context Building"
      assert html =~ "Rendering"

      # Should have green coloring for completed stages
      assert html =~ "green"
    end
  end

  describe "stage formatting" do
    test "formats snake_case stage names to title case" do
      assigns = %{
        error: %{
          stage: :data_loading,
          reason: :error,
          user_message: "Error",
          suggested_action: "Fix"
        },
        retry_event: nil,
        show_technical_details: false,
        max_retries: 3,
        retry_count: 0
      }

      html =
        rendered_to_string(~H"""
        <ReportError.report_error {assigns} />
        """)

      assert html =~ "Data Loading"
      refute html =~ "data_loading"
    end

    test "handles different stage names" do
      for stage <- [:data_loading, :context_building, :rendering, :execution] do
        assigns = %{
          error: %{
            stage: stage,
            reason: :error,
            user_message: "Error",
            suggested_action: "Fix"
          },
          retry_event: nil,
          show_technical_details: false,
          max_retries: 3,
          retry_count: 0
        }

        html =
          rendered_to_string(~H"""
          <ReportError.report_error {assigns} />
          """)

        # Should not contain the raw atom
        refute html =~ to_string(stage)

        # Should contain a formatted version
        formatted =
          stage
          |> Atom.to_string()
          |> String.split("_")
          |> Enum.map_join(" ", &String.capitalize/1)

        assert html =~ formatted
      end
    end
  end

  describe "visual styling" do
    test "includes error styling classes" do
      assigns = %{
        error: %{
          stage: :data_loading,
          reason: :error,
          user_message: "Error",
          suggested_action: "Fix"
        },
        retry_event: nil,
        show_technical_details: false,
        max_retries: 3,
        retry_count: 0
      }

      html =
        rendered_to_string(~H"""
        <ReportError.report_error {assigns} />
        """)

      # Check for Tailwind CSS classes
      assert html =~ "bg-red-"
      assert html =~ "border-red-"
      assert html =~ "text-red-"
    end

    test "includes SVG icons" do
      assigns = %{
        error: %{
          stage: :data_loading,
          reason: :error,
          user_message: "Error",
          suggested_action: "Fix"
        },
        retry_event: nil,
        show_technical_details: false,
        max_retries: 3,
        retry_count: 0
      }

      html =
        rendered_to_string(~H"""
        <ReportError.report_error {assigns} />
        """)

      assert html =~ "<svg"
      assert html =~ "viewBox"
    end
  end
end
