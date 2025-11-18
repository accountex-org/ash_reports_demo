IO.puts("\n=== Checking ETS Tables ===\n")

# Check what ETS tables exist
all_tables = :ets.all()
IO.puts("Total ETS tables: #{length(all_tables)}")

# Check for demo tables
demo_tables = Enum.filter(all_tables, fn table_name ->
  if is_atom(table_name) do
    table_name_str = to_string(table_name)
    String.contains?(table_name_str, "demo") or String.contains?(table_name_str, "customer")
  else
    false
  end
end)

IO.puts("\nDemo-related tables:")
Enum.each(demo_tables, fn table ->
  info = :ets.info(table)
  size = Keyword.get(info, :size, 0)
  IO.puts("  #{inspect(table)}: #{size} records")
end)

# Try to read directly from the Customer ETS table
IO.puts("\n=== Direct ETS Access ===")
customer_table = :demo_customers
if Enum.member?(all_tables, customer_table) do
  size = :ets.info(customer_table)[:size]
  IO.puts("Customer table size: #{size}")

  if size > 0 do
    sample = :ets.tab2list(customer_table) |> Enum.take(3)
    IO.puts("Sample records:")
    Enum.each(sample, fn record ->
      IO.inspect(record, limit: 5)
    end)
  end
else
  IO.puts("Customer table :demo_customers does not exist!")
end

# Try Ash.read
IO.puts("\n=== Ash.read Test ===")
try do
  customers = Ash.read!(AshReportsDemo.Customer, domain: AshReportsDemo.Domain)
  IO.puts("Ash.read returned #{length(customers)} customers")
rescue
  error ->
    IO.puts("Error: #{inspect(error)}")
    IO.puts(Exception.format(:error, error, __STACKTRACE__))
end

IO.puts("\n=== Test Complete ===")
