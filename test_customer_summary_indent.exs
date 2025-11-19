#!/usr/bin/env elixir

# Test customer summary report with indented detail lines

IO.puts("\n=== Testing Customer Summary Report with Indented Details ===\n")

# Data already loaded from pre-generated datasets
IO.puts("Using existing dataset...")

# Generate the customer summary report
IO.puts("\nGenerating customer summary report...")

case AshReportsDemo.run_report(:customer_summary, %{}, format: :pdf) do
  {:ok, result} ->
    # Save the PDF
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    filename = "customer_summary_indented_#{timestamp}.pdf"
    filepath = Path.join([File.cwd!(), "tmp", filename])

    File.mkdir_p!(Path.dirname(filepath))
    File.write!(filepath, result.content)

    IO.puts("\n✅ Report generated successfully!")
    IO.puts("📄 Saved to: #{filepath}")
    IO.puts("📊 Metadata: #{inspect(result.metadata, pretty: true)}")

  {:error, error} ->
    IO.puts("\n❌ Report generation failed:")
    IO.inspect(error, pretty: true)
end

IO.puts("\n=== Test Complete ===\n")
