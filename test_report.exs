# Test the customer summary report
require Logger

# Wait for data
Process.sleep(3000)

Logger.info("Running customer summary report...")

case AshReportsDemo.run_report(:customer_summary, %{}, format: :html) do
  {:ok, result} ->
    Logger.info("✓ Report generated successfully!")
    Logger.info("  Record count: #{result.metadata[:record_count]}")

    # Check the content for grouping
    content = result.content

    if String.contains?(content, "Region:") do
      Logger.info("✓ Found 'Region:' in output - grouping appears to be working")

      # Count occurrences of "Region:"
      count = content |> String.split("Region:") |> length() |> Kernel.-(1)
      Logger.info("  Found #{count} region group headers")
    else
      Logger.warning("✗ No 'Region:' found in output - grouping may not be working")
    end

    # Show first 500 characters of output
    preview = String.slice(content, 0, 500)
    Logger.info("\nFirst 500 characters of output:")
    IO.puts(preview)

  {:error, error} ->
    Logger.error("✗ Report generation failed!")
    Logger.error("  Error: #{inspect(error, pretty: true)}")
end
