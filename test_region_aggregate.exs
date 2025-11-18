require Logger
Logger.configure(level: :debug)

IO.puts("\n=== Testing Region Aggregate ===\n")

# Check if we have data
stats = AshReportsDemo.EtsTables.table_stats()
total = Map.get(stats, :total_records, 0)

if total == 0 do
  IO.puts("No data, generating small dataset...")
  AshReportsDemo.DataGenerator.generate_sample_data(:small)
  IO.puts("Data generated!")
end

# Read a few customers with the region aggregate
IO.puts("\n=== Sample Customer Data with Region ===")
try do
  customers = Ash.read!(AshReportsDemo.Customer,
    domain: AshReportsDemo.Domain,
    load: [:region, :addresses]
  ) |> Enum.take(5)

  IO.puts("Found #{length(customers)} customers")

  Enum.each(customers, fn customer ->
    IO.puts("\nCustomer: #{customer.name}")
    IO.puts("  Region aggregate: #{inspect(customer.region)}")
    IO.puts("  Addresses: #{length(customer.addresses)}")
    if length(customer.addresses) > 0 do
      first_addr = List.first(customer.addresses)
      IO.puts("  First address state: #{first_addr.state}")
    end
  end)
rescue
  error ->
    IO.puts("Error reading customers: #{inspect(error)}")
    IO.puts(Exception.format(:error, error, __STACKTRACE__))
end

# Now try running the report
IO.puts("\n=== Running Customer Summary Report ===")
case AshReportsDemo.run_report(:customer_summary, %{}, format: :html) do
  {:ok, result} ->
    IO.puts("\n✓ Report generated successfully!")
    IO.puts("  Record count: #{result.record_count}")
    IO.puts("  Content size: #{byte_size(result.content)} bytes")

  {:error, error} ->
    IO.puts("\n✗ Report failed:")
    IO.inspect(error, pretty: true, limit: :infinity)
end

IO.puts("\n=== Test Complete ===")
