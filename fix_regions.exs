require Logger
classify = fn state -> cond do
  state in ~w(CA OR WA NV AZ UT CO ID MT WY NM AK HI California Oregon Washington Nevada Arizona Utah Colorado Idaho Montana Wyoming) -> "West"
  state in ~w(ME NH VT MA RI CT NY NJ PA Maine Vermont Massachusetts Connecticut) -> "Northeast"
  state in ~w(MD DE VA WV NC SC GA FL AL MS TN KY Maryland Delaware Virginia Florida Georgia Alabama Mississippi Tennessee Kentucky) -> "Southeast"
  state in ~w(OH IN IL MI WI MN IA MO ND SD NE KS Ohio Indiana Illinois Michigan Wisconsin Minnesota Iowa Missouri Nebraska Kansas) -> "Midwest"
  state in ~w(TX OK AR LA Texas Oklahoma Arkansas Louisiana) -> "Southwest"
  true -> "Unknown"
end end
Process.sleep(3000)
customers = Ash.read!(AshReportsDemo.Customer, domain: AshReportsDemo.Domain, load: [:addresses])
Logger.info("Updating #{length(customers)} customers...")
Enum.each(customers, fn c ->
  addr = Enum.find(c.addresses, &(&1.primary == true))
  if addr, do: c |> Ash.Changeset.for_update(:update, %{region_name: classify.(addr.state)}) |> Ash.update!(domain: AshReportsDemo.Domain)
  IO.write(".")
end)
IO.puts("\n✓ Done!")
Ash.read!(AshReportsDemo.Customer, domain: AshReportsDemo.Domain) |> Enum.group_by(& &1.region_name) |> Enum.map(fn {r, cs} -> {r, length(cs)} end) |> Enum.sort() |> IO.inspect(label: "Distribution")
