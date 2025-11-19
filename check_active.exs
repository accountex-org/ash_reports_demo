Process.sleep(3000)
active = Ash.read!(AshReportsDemo.Customer, domain: AshReportsDemo.Domain) |> Enum.filter(&(&1.status == :active))
IO.puts("Active customers: #{length(active)}")
active |> Enum.group_by(& &1.region_name) |> Enum.map(fn {r, cs} -> {r, length(cs)} end) |> Enum.sort() |> IO.inspect(label: "Active by region")
