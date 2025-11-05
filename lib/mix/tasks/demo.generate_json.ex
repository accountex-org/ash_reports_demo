defmodule Mix.Tasks.Demo.GenerateJson do
  @moduledoc """
  Mix task to generate and save all demo datasets to JSON files.

  This task generates all four datasets (small, medium, large, huge) and saves
  them to the priv/demo_data/ directory as JSON files. This allows for much
  faster application startup by loading pre-generated data instead of generating
  it on-the-fly.

  ## Usage

      mix demo.generate_json

  ## Options

      --only VOLUME    Generate only the specified dataset (small, medium, large, or huge)

  ## Examples

      # Generate all datasets
      mix demo.generate_json

      # Generate only the huge dataset
      mix demo.generate_json --only huge

  ## Output

  JSON files are saved to:
  - priv/demo_data/small.json
  - priv/demo_data/medium.json
  - priv/demo_data/large.json
  - priv/demo_data/huge.json

  Each file contains all records for all tables in that dataset.
  """

  use Mix.Task

  require Logger

  @shortdoc "Generate and save demo datasets to JSON files"

  @impl Mix.Task
  def run(args) do
    # Disable automatic data generation on startup
    System.put_env("SKIP_AUTO_GENERATION", "true")

    # Start the application to get access to GenServers
    Mix.Task.run("app.start")

    # Wait for application to fully start
    Process.sleep(500)

    {opts, _, _} = OptionParser.parse(args, switches: [only: :string])

    volumes =
      case opts[:only] do
        nil -> [:small, :medium, :large, :huge]
        volume_str -> [String.to_atom(volume_str)]
      end

    # Ensure the output directory exists
    output_dir = Path.join([:code.priv_dir(:ash_reports_demo), "demo_data"])
    File.mkdir_p!(output_dir)

    Mix.shell().info("Generating datasets to #{output_dir}...")

    for volume <- volumes do
      Mix.shell().info("\nGenerating #{volume} dataset...")
      start_time = System.monotonic_time(:millisecond)

      case generate_and_save_dataset(volume, output_dir) do
        {:ok, file_path, stats} ->
          duration = System.monotonic_time(:millisecond) - start_time
          file_size = File.stat!(file_path).size |> format_bytes()

          Mix.shell().info(
            "✓ #{volume} dataset saved to #{Path.basename(file_path)} (#{file_size}, #{duration}ms)"
          )

          Mix.shell().info("  Records: #{inspect(stats)}")

        {:error, reason} ->
          Mix.shell().error("✗ Failed to generate #{volume} dataset: #{reason}")
      end
    end

    Mix.shell().info("\n✓ Dataset generation complete!")
  end

  defp generate_and_save_dataset(volume, output_dir) do
    # Generate the dataset using the DataGenerator
    case AshReportsDemo.DataGenerator.generate_dataset_for_export(volume) do
      {:ok, dataset_data} ->
        # Save to JSON file
        file_path = Path.join(output_dir, "#{volume}.json")
        json_data = Jason.encode!(dataset_data, pretty: true)
        File.write!(file_path, json_data)

        # Calculate stats
        stats =
          dataset_data
          |> Enum.map(fn {table, records} -> {table, length(records)} end)
          |> Enum.into(%{})

        {:ok, file_path, stats}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
end
