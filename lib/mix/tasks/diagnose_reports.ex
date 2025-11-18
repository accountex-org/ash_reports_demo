defmodule Mix.Tasks.DiagnoseReports do
  @moduledoc """
  Diagnostic task to check report generation system health.

  Usage: mix diagnose_reports
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("\n=== AshReports Demo Diagnostics ===\n")

    # 1. Check ETS table data
    check_ets_tables()

    # 2. Check report definitions
    check_report_definitions()

    # 3. Try generating a simple report
    test_report_generation()

    IO.puts("\n=== Diagnostics Complete ===\n")
  end

  defp check_ets_tables() do
    IO.puts("1. Checking ETS Tables...")

    stats = AshReportsDemo.EtsTables.table_stats()

    Enum.each(stats, fn {table_name, count} ->
      status = if count > 0, do: "✓", else: "✗"
      IO.puts("  #{status} #{table_name}: #{count} records")
    end)

    total_records = stats |> Map.values() |> Enum.sum()

    if total_records == 0 do
      IO.puts("\n  ⚠️  WARNING: No data in ETS tables!")
      IO.puts("     Run: AshReportsDemo.DataGenerator.generate_data(:small)")
    else
      IO.puts("\n  ✓ Data exists (#{total_records} total records)")
    end

    IO.puts("")
  end

  defp check_report_definitions() do
    IO.puts("2. Checking Report Definitions...")

    reports = AshReports.Info.reports(AshReportsDemo.Domain)

    if Enum.empty?(reports) do
      IO.puts("  ✗ No reports defined!")
    else
      IO.puts("  ✓ Found #{length(reports)} reports:")

      Enum.each(reports, fn report ->
        IO.puts("    - #{report.name}")
        IO.puts("      Variables: #{length(report.variables || [])}")
        IO.puts("      Groups: #{length(report.groups || [])}")
        IO.puts("      Bands: #{length(report.bands || [])}")
      end)
    end

    IO.puts("")
  end

  defp test_report_generation() do
    IO.puts("3. Testing Report Generation...")

    # Try generating a simple HTML report
    IO.puts("  Attempting to generate :customer_summary report in HTML format...")

    try do
      case AshReportsDemo.run_report(:customer_summary, %{}, format: :html) do
        {:ok, result} ->
          IO.puts("  ✓ Report generated successfully!")
          IO.puts("    Format: #{result.format}")
          IO.puts("    Content size: #{byte_size(result.content)} bytes")
          IO.puts("    Record count: #{result.record_count}")

        {:error, error} ->
          IO.puts("  ✗ Report generation failed:")
          IO.puts("    #{inspect(error, pretty: true)}")
      end
    rescue
      error ->
        IO.puts("  ✗ Exception during report generation:")
        IO.puts("    #{Exception.message(error)}")
        IO.puts("    #{Exception.format(:error, error, __STACKTRACE__)}")
    end

    IO.puts("")
  end
end
