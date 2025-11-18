require Logger
Logger.configure(level: :debug)

IO.puts("\n=== Simple Region Aggregate Test ===\n")

# Check if we have any customers
IO.puts("Checking for existing customers...")
customers = Ash.read!(AshReportsDemo.Customer, domain: AshReportsDemo.Domain)
IO.puts("Found #{length(customers)} customers")

if length(customers) == 0 do
  IO.puts("\nNo customers found. Please ensure data is loaded.")
  System.halt(0)
end

# Read customers with region and addresses loaded
IO.puts("\n=== Reading Customers with Region ===")
customers_with_region = Ash.read!(AshReportsDemo.Customer,
  domain: AshReportsDemo.Domain,
  load: [:region, :addresses]
)

IO.puts("\nCustomer Details:")
Enum.take(customers_with_region, 5) |> Enum.each(fn customer ->
  IO.puts("\n#{customer.name}:")
  IO.puts("  region aggregate: #{inspect(customer.region)}")
  IO.puts("  addresses count: #{length(customer.addresses)}")

  if length(customer.addresses) > 0 do
    IO.puts("  addresses:")
    Enum.each(customer.addresses, fn addr ->
      IO.puts("    - #{addr.city}, #{addr.state} (primary: #{addr.primary}, active: #{addr.active})")
    end)

    # Check what the aggregate SHOULD be
    primary_addrs = Enum.filter(customer.addresses, & &1.primary)
    IO.puts("  primary addresses count: #{length(primary_addrs)}")
    if length(primary_addrs) > 0 do
      first_primary = List.first(primary_addrs)
      IO.puts("  first primary state: #{first_primary.state}")
    end
  end
end)

# Now test with a query that includes the aggregate
IO.puts("\n=== Testing Query with Region in Sort ===")
query = AshReportsDemo.Customer
  |> Ash.Query.new()
  |> Ash.Query.load([:region, :addresses])
  |> Ash.Query.sort([region: :asc])

results = Ash.read!(query, domain: AshReportsDemo.Domain)
IO.puts("\nQuery returned #{length(results)} results")

Enum.take(results, 3) |> Enum.each(fn customer ->
  IO.puts("\n#{customer.name}:")
  IO.puts("  region: #{inspect(customer.region)}")
  IO.puts("  addresses: #{length(customer.addresses)}")
end)

IO.puts("\n=== Test Complete ===")
