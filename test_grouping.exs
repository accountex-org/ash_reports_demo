require Logger
Logger.configure(level: :debug)

IO.puts("\n=== Testing Group Sorting with Addresses ===\n")

# Check if we have data
stats = AshReportsDemo.EtsTables.table_stats()
total = Map.get(stats, :total_records, 0)

if total == 0 do
  IO.puts("No data, generating small dataset...")
  AshReportsDemo.DataGenerator.generate_sample_data(:small)
  IO.puts("Data generated!")
end

# Read a few customers to check addresses
IO.puts("\n=== Sample Customer Data ===")
customers = Ash.read!(AshReportsDemo.Customer,
  domain: AshReportsDemo.Domain,
  load: [:addresses]
) |> Enum.take(3)

Enum.each(customers, fn customer ->
  IO.puts("\nCustomer: #{customer.name}")
  IO.puts("  Addresses: #{length(customer.addresses)}")
  if length(customer.addresses) > 0 do
    first_addr = List.first(customer.addresses)
    IO.puts("  First address state: #{first_addr.state}")
  end
end)

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
