IO.puts("\n=== Checking ETS Tables ===")
stats = AshReportsDemo.EtsTables.table_stats()
IO.inspect(stats, label: "Table Stats")

total = Map.get(stats, :total_records, 0)
IO.puts("Total records: #{total}")

if total == 0 do
  IO.puts("\n=== No data found, generating... ===")
  AshReportsDemo.DataGenerator.generate_sample_data(:small)
  IO.puts("Data generated!")
  new_stats = AshReportsDemo.EtsTables.table_stats()
  IO.inspect(new_stats, label: "New Table Stats")
end

IO.puts("\n=== Testing Report Generation ===")
IO.puts("Starting report generation...")

try do
  case AshReportsDemo.run_report(:customer_summary, %{}, format: :html) do
    {:ok, result} ->
      IO.puts("✓ Report generated successfully!")
      IO.puts("  Format: #{result.format}")
      IO.puts("  Content size: #{byte_size(result.content)} bytes")
      IO.puts("  Record count: #{result.record_count}")

      # Show first 500 chars of content
      preview = String.slice(result.content, 0, 500)
      IO.puts("\n=== Content Preview ===")
      IO.puts(preview)
      IO.puts("...")

    {:error, error} ->
      IO.puts("✗ Report generation failed:")
      IO.inspect(error, pretty: true, limit: :infinity)
  end
rescue
  error ->
    IO.puts("✗ Exception during report generation:")
    IO.puts(Exception.message(error))
    IO.puts(Exception.format(:error, error, __STACKTRACE__))
end

IO.puts("\n=== Test Complete ===")
