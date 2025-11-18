require Logger
Logger.configure(level: :debug)

IO.puts("\n=== Testing Region Aggregate Loading ===\n")

# First, create some test data directly using Ash
IO.puts("Creating test customers with addresses...")

# Create a customer type first
{:ok, customer_type} = Ash.create!(AshReportsDemo.CustomerType, %{
  name: "Gold",
  tier_level: 3
}, domain: AshReportsDemo.Domain)
|> then(fn result -> {:ok, result} end)
|> IO.inspect(label: "Created customer type")

# Create a customer
{:ok, customer} = AshReportsDemo.Customer
|> Ash.Changeset.for_create(:create, %{
  name: "Test Customer",
  email: "test@example.com",
  customer_type_id: customer_type.id,
  status: :active
}, domain: AshReportsDemo.Domain)
|> Ash.create!()
|> then(fn result -> {:ok, result} end)
|> IO.inspect(label: "Created customer")

# Create an address for the customer
{:ok, address} = AshReportsDemo.CustomerAddress
|> Ash.Changeset.for_create(:create, %{
  customer_id: customer.id,
  street: "123 Main St",
  city: "San Francisco",
  state: "CA",
  zip_code: "94102",
  country: "USA",
  address_type: :billing,
  primary: true
}, domain: AshReportsDemo.Domain)
|> Ash.create!()
|> then(fn result -> {:ok, result} end)
|> IO.inspect(label: "Created address")

IO.puts("\n=== Reading Customer with Region Aggregate ===")

# Now read the customer back with the region aggregate
customer_with_region = Ash.get!(AshReportsDemo.Customer, customer.id,
  domain: AshReportsDemo.Domain,
  load: [:region, :addresses]
)

IO.puts("\nCustomer: #{customer_with_region.name}")
IO.puts("  Region aggregate: #{inspect(customer_with_region.region)}")
IO.puts("  Addresses count: #{length(customer_with_region.addresses)}")
if length(customer_with_region.addresses) > 0 do
  IO.puts("  First address state: #{List.first(customer_with_region.addresses).state}")
end

# Try reading with a query
IO.puts("\n=== Reading via Query with Region ===")
customers = Ash.read!(AshReportsDemo.Customer,
  domain: AshReportsDemo.Domain,
  load: [:region, :addresses]
)

IO.puts("Found #{length(customers)} customers")
Enum.each(customers, fn c ->
  IO.puts("\nCustomer: #{c.name}")
  IO.puts("  Region: #{inspect(c.region)}")
  IO.puts("  Addresses: #{length(c.addresses)}")
end)

# Now test the query builder
IO.puts("\n=== Testing QueryBuilder ===")
report = AshReports.Domain.Info.report(AshReportsDemo.Domain, :customer_summary)
IO.inspect(report.groups, label: "Report groups")

case AshReports.QueryBuilder.build(report, %{}) do
  {:ok, query} ->
    IO.puts("Query built successfully")
    IO.inspect(query.load, label: "Query loads")
    IO.inspect(query.sort, label: "Query sort")

    # Execute the query
    IO.puts("\n=== Executing Query ===")
    results = Ash.read!(query, domain: AshReportsDemo.Domain)
    IO.puts("Got #{length(results)} results")
    Enum.take(results, 3) |> Enum.each(fn record ->
      IO.puts("\nRecord: #{record.name}")
      IO.puts("  Region: #{inspect(Map.get(record, :region))}")
      IO.puts("  Has addresses key: #{Map.has_key?(record, :addresses)}")
    end)

  {:error, error} ->
    IO.puts("Query build failed:")
    IO.inspect(error)
end

IO.puts("\n=== Test Complete ===")
