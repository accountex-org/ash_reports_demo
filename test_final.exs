require Logger
Process.sleep(6000)

stats = AshReportsDemo.EtsTables.table_stats()
IO.inspect(stats.tables, label: "Table stats after 6 seconds")

customers = Ash.read!(AshReportsDemo.Customer, domain: AshReportsDemo.Domain)
IO.puts("Customers loaded: #{length(customers)}")

if length(customers) > 0 do
  IO.puts("SUCCESS: Data loaded correctly!")
else
  IO.puts("FAILURE: No data loaded")
end
