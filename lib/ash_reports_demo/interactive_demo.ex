defmodule AshReportsDemo.InteractiveDemo do
  @moduledoc """
  Interactive demo module for AshReports demonstration.

  Provides guided demo experiences for new users to explore the system capabilities
  without needing to understand the underlying implementation details.
  """

  require Logger

  @doc """
  Start the interactive demo experience.

  Provides a guided walkthrough of the AshReports system including:
  - Data generation with different volumes
  - Report execution and rendering
  - System cleanup and reset
  """
  def start do
    IO.puts("""

    🚀 Welcome to AshReports Interactive Demo!

    This demo will walk you through the complete AshReports system:
    • Generate realistic sample data
    • Execute different types of reports
    • Explore HTML rendering capabilities
    • Clean up when finished

    """)

    case get_user_choice("Would you like to start the demo?", ["yes", "no"]) do
      "yes" ->
        run_guided_demo()

      "no" ->
        IO.puts("Demo cancelled. Run AshReportsDemo.InteractiveDemo.start() anytime!")
        :cancelled
    end
  end

  @doc """
  Quick automated demo without user interaction.

  Runs through a complete demo cycle automatically for testing or presentation purposes.
  """
  def quick_demo do
    IO.puts("🏃‍♂️ Running Quick Demo...")

    with :ok <- generate_demo_data(:small),
         :ok <- demonstrate_reports(),
         :ok <- cleanup_demo() do
      IO.puts("✅ Quick demo completed successfully!")
      :ok
    else
      {:error, reason} ->
        IO.puts("❌ Quick demo failed: #{reason}")
        {:error, reason}
    end
  end

  # Private implementation

  defp run_guided_demo do
    IO.puts("🎯 Starting guided demo experience...\n")

    with :ok <- demo_data_generation(),
         :ok <- demo_report_execution(),
         :ok <- demo_cleanup() do
      IO.puts("""

      🎉 Demo completed successfully!

      You've seen how AshReports can:
      ✅ Generate realistic sample data with referential integrity
      ✅ Execute multiple report types with different parameters  
      ✅ Render reports as HTML with professional styling
      ✅ Handle data cleanup and reset operations

      Try exploring the system further with:
      • AshReportsDemo.generate_sample_data(:medium) - More data
      • AshReportsDemo.generate_sample_data(:large) - Full dataset
      • Different report parameters and filters

      Thanks for trying AshReports! 🚀
      """)

      :ok
    else
      {:error, reason} ->
        IO.puts("❌ Demo encountered an error: #{reason}")
        IO.puts("Don't worry - you can try again or contact support.")
        {:error, reason}
    end
  end

  defp demo_data_generation do
    IO.puts("📊 Step 1: Data Generation")
    IO.puts("We'll generate sample data to power our reports.")

    volume =
      case get_user_choice(
             "What size dataset would you like?",
             ["small", "medium", "large"],
             "small"
           ) do
        choice when choice in ["small", "medium", "large"] -> String.to_atom(choice)
        _ -> :small
      end

    IO.puts("Generating #{volume} dataset...")

    case AshReportsDemo.generate_sample_data(volume) do
      :ok ->
        stats = AshReportsDemo.data_summary()

        IO.puts("""

        ✅ Data generation successful!
        Generated data:
        • #{stats.customers} customers
        • #{stats.products} products
        • #{stats.invoices} invoices with line items

        """)

        :ok

      {:error, reason} ->
        IO.puts("❌ Data generation failed: #{reason}")
        {:error, reason}
    end
  end

  defp demo_report_execution do
    IO.puts("📈 Step 2: Report Execution")
    IO.puts("Now let's run some reports on your generated data.")

    reports = [
      {:customer_summary, "Customer Summary Report"},
      {:product_inventory, "Product Inventory Report"},
      {:invoice_details, "Invoice Details Report"},
      {:financial_summary, "Financial Summary Report"}
    ]

    Enum.reduce_while(reports, :ok, fn {report_type, report_name}, :ok ->
      IO.puts("\n🔍 Running #{report_name}...")

      case run_sample_report(report_type) do
        :ok ->
          IO.puts("✅ #{report_name} completed successfully")
          {:cont, :ok}

        {:error, reason} ->
          IO.puts("❌ #{report_name} failed: #{reason}")
          {:halt, {:error, reason}}
      end
    end)
  end

  defp demo_cleanup do
    IO.puts("\n🧹 Step 3: Cleanup")

    case get_user_choice(
           "Would you like to reset the demo data?",
           ["yes", "no"],
           "yes"
         ) do
      "yes" ->
        IO.puts("Cleaning up demo data...")

        case AshReportsDemo.reset_data() do
          :ok ->
            IO.puts("✅ Demo data cleaned up successfully")
            :ok

          {:error, reason} ->
            IO.puts("❌ Cleanup failed: #{reason}")
            {:error, reason}
        end

      "no" ->
        IO.puts("Demo data preserved for further exploration")
        :ok
    end
  end

  defp generate_demo_data(volume) do
    case AshReportsDemo.generate_sample_data(volume) do
      :ok -> :ok
      {:error, reason} -> {:error, "Data generation failed: #{reason}"}
    end
  end

  defp demonstrate_reports do
    # Run a quick sample of each report type to verify they work
    reports = [:customer_summary, :product_inventory, :invoice_details, :financial_summary]

    Enum.reduce_while(reports, :ok, fn report_type, :ok ->
      case run_sample_report(report_type) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp run_sample_report(report_type) do
    # Run report with basic parameters and HTML format
    case AshReportsDemo.run_report(report_type, %{}, format: :html) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, inspect(reason)}
    end
  rescue
    e -> {:error, "Report execution error: #{inspect(e)}"}
  end

  defp cleanup_demo do
    case AshReportsDemo.reset_data() do
      :ok -> :ok
      {:error, reason} -> {:error, "Cleanup failed: #{reason}"}
    end
  end

  defp get_user_choice(prompt, options, default \\ nil) do
    options_str = Enum.join(options, "/")
    default_str = if default, do: " (default: #{default})", else: ""

    IO.gets("#{prompt} [#{options_str}]#{default_str}: ")
    |> String.trim()
    |> case do
      "" when not is_nil(default) -> default
      choice -> String.downcase(choice)
    end
  end
end
