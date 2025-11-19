# Check customer status and region distribution
require Logger

Process.sleep(3000)

customers = Ash.read!(AshReportsDemo.Customer, domain: AshReportsDemo.Domain)

Logger.info("Total customers: #{length(customers)}")

# Status distribution
status_dist =
  customers
  |> Enum.group_by(& &1.status)
  |> Enum.map(fn {status, custs} -> {status, length(custs)} end)
  |> Enum.sort()

Logger.info("\nStatus distribution:")
Enum.each(status_dist, fn {status, count} ->
  Logger.info("  #{status}: #{count}")
end)

# Active customers only
active_customers = Enum.filter(customers, &(&1.status == :active))
Logger.info("\nActive customers: #{length(active_customers)}")

# Region distribution for active customers
active_regions =
  active_customers
  |> Enum.group_by(& &1.region_name)
  |> Enum.map(fn {region, custs} -> {region, length(custs)} end)
  |> Enum.sort()

Logger.info("\nRegion distribution (active only):")
Enum.each(active_regions, fn {region, count} ->
  Logger.info("  #{region}: #{count}")
end)

# Region distribution for ALL customers
all_regions =
  customers
  |> Enum.group_by(& &1.region_name)
  |> Enum.map(fn {region, custs} -> {region, length(custs)} end)
  |> Enum.sort()

Logger.info("\nRegion distribution (all customers):")
Enum.each(all_regions, fn {region, count} ->
  Logger.info("  #{region}: #{count}")
end)
