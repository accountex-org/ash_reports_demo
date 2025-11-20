defmodule AshReportsDemo.DataGenerator do
  @moduledoc """
  GenServer that generates realistic test data using Faker library.

  Provides seeding functions for all demo resources with proper
  relationship integrity and configurable data volumes.
  """

  use GenServer

  require Logger

  alias AshReportsDemo.{
    Customer,
    CustomerAddress,
    CustomerType,
    Domain,
    EtsTables,
    Inventory,
    Invoice,
    InvoiceLineItem,
    Product,
    ProductCategory
  }

  @data_volumes %{
    small: %{
      customer_types: 4,
      product_categories: 5,
      customers: 25,
      products: 100,
      invoices: 75,
      addresses_per_customer: 1..2,
      line_items_per_invoice: 1..5
    },
    medium: %{
      customer_types: 4,
      product_categories: 5,
      customers: 100,
      products: 500,
      invoices: 300,
      addresses_per_customer: 1..3,
      line_items_per_invoice: 2..8
    },
    large: %{
      customer_types: 4,
      product_categories: 5,
      customers: 1000,
      products: 2000,
      invoices: 5000,
      addresses_per_customer: 1..4,
      line_items_per_invoice: 1..12
    },
    huge: %{
      customer_types: 4,
      product_categories: 5,
      customers: 10_000,
      products: 20_000,
      invoices: 50_000,
      addresses_per_customer: 1..4,
      line_items_per_invoice: 1..12
    }
  }

  # Public API

  @doc """
  Start the data generator GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate sample data with specified volume.
  """
  @spec generate_sample_data(atom()) :: :ok | {:error, String.t()}
  def generate_sample_data(volume \\ :medium) do
    GenServer.call(__MODULE__, {:switch_to_dataset, volume}, 5_000)
  end

  @doc """
  Generate all datasets at startup in parallel.
  """
  @spec generate_all_datasets() :: :ok | {:error, String.t()}
  def generate_all_datasets do
    GenServer.call(__MODULE__, :generate_all_datasets, :infinity)
  end

  @doc """
  Get the current active dataset volume.
  """
  @spec get_current_dataset() :: atom()
  def get_current_dataset do
    GenServer.call(__MODULE__, :get_current_dataset)
  end

  @doc """
  Get entity counts for the current dataset.
  Returns pre-calculated counts without querying ETS.
  """
  @spec get_current_dataset_counts() :: map()
  def get_current_dataset_counts do
    GenServer.call(__MODULE__, :get_current_dataset_counts)
  end

  @doc """
  Get available datasets that have been generated.
  """
  @spec get_available_datasets() :: [atom()]
  def get_available_datasets do
    GenServer.call(__MODULE__, :get_available_datasets)
  end

  @doc """
  Reset all data to clean state.
  """
  @spec reset_data() :: :ok
  def reset_data do
    # Use longer timeout to allow previous operations to complete (especially large datasets)
    GenServer.call(__MODULE__, :reset, 60_000)
  end

  @doc """
  Get current data statistics.
  """
  @spec data_stats() :: map()
  def data_stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Generate foundation data (customer types and product categories).
  """
  @spec generate_foundation_data() :: :ok | {:error, String.t()}
  def generate_foundation_data do
    GenServer.call(__MODULE__, :generate_foundation_data, 10_000)
  end

  @doc """
  Generate customer data.
  """
  @spec generate_customer_data() :: :ok | {:error, String.t()}
  def generate_customer_data do
    GenServer.call(__MODULE__, :generate_customer_data, 15_000)
  end

  @doc """
  Generate product data.
  """
  @spec generate_product_data() :: :ok | {:error, String.t()}
  def generate_product_data do
    GenServer.call(__MODULE__, :generate_product_data, 15_000)
  end

  @doc """
  Generate invoice data.
  """
  @spec generate_invoice_data() :: :ok | {:error, String.t()}
  def generate_invoice_data do
    GenServer.call(__MODULE__, :generate_invoice_data, 20_000)
  end

  @doc """
  Validate referential integrity of generated data.
  """
  @spec validate_data_integrity() :: {:ok, map()} | {:error, String.t()}
  def validate_data_integrity do
    GenServer.call(__MODULE__, :validate_integrity, 10_000)
  end

  @doc """
  Generate a dataset and return the data structure for export to JSON.

  This function is used by the mix task to generate datasets that will be
  saved to JSON files. It generates the data in-memory and returns the
  complete dataset structure without loading it into the active state.

  ## Parameters
    - volume: The dataset volume to generate (:small, :medium, :large, or :huge)

  ## Returns
    - `{:ok, dataset_data}` - Map of table names to lists of records
    - `{:error, reason}` - Error during generation
  """
  @spec generate_dataset_for_export(atom()) :: {:ok, map()} | {:error, String.t()}
  def generate_dataset_for_export(volume) do
    GenServer.call(__MODULE__, {:generate_for_export, volume}, :infinity)
  end

  @doc """
  Load a dataset from a JSON file.

  This function reads a JSON file containing a pre-generated dataset and
  loads it into ETS tables, making it the active dataset.

  ## Parameters
    - file_path: Path to the JSON file containing the dataset

  ## Returns
    - `:ok` - Dataset loaded successfully
    - `{:error, reason}` - Error reading file or loading data
  """
  @spec load_dataset_from_json(String.t()) :: :ok | {:error, String.t()}
  def load_dataset_from_json(file_path) do
    GenServer.call(__MODULE__, {:load_from_json, file_path}, 60_000)
  end

  # GenServer implementation

  @impl true
  def init(_opts) do
    # Initialize with clean state
    state = %{
      generation_in_progress: false,
      current_dataset: :small,
      available_datasets: [],
      # Store only counts per dataset, not the data
      dataset_metadata: %{},
      data_dir: nil,
      last_generated: nil
    }

    Logger.info("AshReportsDemo DataGenerator started")

    # Skip automatic generation if disabled via environment variable
    unless System.get_env("SKIP_AUTO_GENERATION") == "true" do
      # Try to load from JSON first, fall back to generation
      send(self(), :load_or_generate_datasets_async)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:load_or_generate_datasets_async, state) do
    if state.generation_in_progress do
      {:noreply, state}
    else
      # Check which pre-generated JSON files exist
      priv_dir = Application.app_dir(:ash_reports_demo, "priv")
      data_dir = Path.join(priv_dir, "demo_data")

      available_volumes =
        [:small, :medium, :large, :huge]
        |> Enum.filter(fn volume ->
          file_path = Path.join(data_dir, "#{volume}.json")
          File.exists?(file_path)
        end)

      if available_volumes != [] do
        Logger.info("Found pre-generated datasets: #{inspect(available_volumes)}")

        # Load the first available dataset (prefer small)
        initial_dataset =
          cond do
            :small in available_volumes -> :small
            :medium in available_volumes -> :medium
            :large in available_volumes -> :large
            :huge in available_volumes -> :huge
            true -> hd(available_volumes)
          end

        Logger.info("Loading #{initial_dataset} dataset into memory...")

        parent = self()

        Task.start(fn ->
          # First, calculate metadata (counts) for all available datasets
          Logger.info("Calculating metadata for all datasets...")

          metadata_result =
            Enum.reduce_while(available_volumes, {:ok, %{}}, fn volume, {:ok, acc} ->
              file_path = Path.join(data_dir, "#{volume}.json")

              case calculate_dataset_metadata(file_path) do
                {:ok, counts} ->
                  Logger.info("#{volume}: #{inspect(counts)}")
                  {:cont, {:ok, Map.put(acc, volume, counts)}}

                {:error, reason} ->
                  {:halt, {:error, volume, reason}}
              end
            end)

          case metadata_result do
            {:ok, all_metadata} ->
              # For multitenancy: Load ALL datasets into ETS (each with its own dataset_id)
              Logger.info("Loading ALL datasets into memory for multitenancy...")

              # Clear data before loading all datasets
              EtsTables.clear_all_data()

              load_results =
                Enum.reduce_while(available_volumes, :ok, fn volume, :ok ->
                  file_path = Path.join(data_dir, "#{volume}.json")
                  Logger.info("Loading #{volume} dataset...")

                  case load_dataset_from_json_file(file_path) do
                    {:ok, ^volume} ->
                      Logger.info("#{volume} dataset loaded successfully")
                      {:cont, :ok}

                    {:error, reason} ->
                      Logger.error("Failed to load #{volume} dataset: #{reason}")
                      {:halt, {:error, volume, reason}}
                  end
                end)

              case load_results do
                :ok ->
                  send(
                    parent,
                    {:datasets_ready, initial_dataset, available_volumes, data_dir, all_metadata}
                  )

                {:error, volume, reason} ->
                  Logger.error("Failed to load #{volume} dataset: #{reason}")
                  send(parent, :datasets_failed_to_load)
              end

            {:error, volume, reason} ->
              Logger.error("Failed to calculate metadata for #{volume}: #{reason}")
              send(parent, :datasets_failed_to_load)
          end
        end)

        {:noreply, %{state | generation_in_progress: true}}
      else
        Logger.warning("No pre-generated datasets found. Please run: mix demo.generate_json")
        Logger.info("Application started without data. Generate datasets to use the demo.")
        {:noreply, state}
      end
    end
  end

  @impl true
  def handle_info({:datasets_ready, loaded_dataset, available_volumes, data_dir, metadata}, state) do
    Logger.info("Successfully loaded #{loaded_dataset} dataset and metadata for all datasets")

    updated_state = %{
      state
      | generation_in_progress: false,
        available_datasets: available_volumes,
        current_dataset: loaded_dataset,
        data_dir: data_dir,
        dataset_metadata: metadata
    }

    {:noreply, updated_state}
  end

  @impl true
  def handle_info(:datasets_failed_to_load, state) do
    updated_state = %{state | generation_in_progress: false}
    {:noreply, updated_state}
  end

  @impl true
  def handle_info(:generate_all_datasets_async, state) do
    if state.generation_in_progress do
      {:noreply, state}
    else
      Logger.info("Starting parallel generation of all datasets...")

      # Start async task to generate all datasets
      Task.start(fn ->
        case generate_all_datasets_internal() do
          :ok ->
            send(self(), :all_datasets_generated)

          {:error, reason} ->
            send(self(), {:all_datasets_failed, reason})
        end
      end)

      {:noreply, %{state | generation_in_progress: true}}
    end
  end

  @impl true
  def handle_info(:all_datasets_generated, state) do
    Logger.info("All datasets generated successfully!")

    updated_state = %{
      state
      | generation_in_progress: false,
        available_datasets: [:small, :medium, :large, :huge],
        current_dataset: :small
    }

    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:store_datasets, datasets}, state) do
    {:noreply, %{state | datasets: datasets}}
  end

  @impl true
  def handle_info({:switch_dataset, volume}, state) do
    # For multitenancy: All datasets are already loaded at startup
    # Just switch the current_dataset
    if volume in state.available_datasets do
      Logger.info("Switched to #{volume} dataset")
      {:noreply, %{state | current_dataset: volume}}
    else
      Logger.warning("Dataset #{volume} not available")
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:all_datasets_failed, reason}, state) do
    Logger.error("Failed to generate all datasets: #{reason}")
    # Fallback to generating just small dataset
    send(self(), :maybe_generate_initial_data)
    {:noreply, %{state | generation_in_progress: false}}
  end

  @impl true
  def handle_info(:maybe_generate_initial_data, state) do
    # Check if data already exists
    %{tables: tables} = EtsTables.table_stats()

    total_records =
      tables
      |> Enum.reduce(0, fn {_table_name, %{size: size}}, acc -> acc + size end)

    if total_records == 0 do
      Logger.info("No data found - generating small sample dataset...")

      case generate_data_internal(:small) do
        :ok ->
          Logger.info("Initial sample data generated successfully")
          {:noreply, %{state | current_dataset: :small, last_generated: DateTime.utc_now()}}

        {:error, reason} ->
          Logger.error("Failed to generate initial data: #{inspect(reason)}")
          {:noreply, state}
      end
    else
      Logger.info("Existing data found (#{total_records} records) - skipping initial generation")
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:generate_all_datasets, _from, state) do
    if state.generation_in_progress do
      {:reply, {:error, "Generation already in progress"}, state}
    else
      case generate_all_datasets_internal() do
        :ok ->
          updated_state = %{
            state
            | available_datasets: [:small, :medium, :large, :huge],
              current_dataset: :small
          }

          {:reply, :ok, updated_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call({:switch_to_dataset, volume}, _from, state) do
    if volume in state.available_datasets do
      # For multitenancy: All datasets are already loaded at startup
      # Just switch the current_dataset (which affects get_current_dataset_counts)
      Logger.info("Switched to #{volume} dataset (already in memory)")
      {:reply, :ok, %{state | current_dataset: volume}}
    else
      {:reply,
       {:error,
        "Dataset #{volume} not available. Available: #{inspect(state.available_datasets)}"},
       state}
    end
  end

  @impl true
  def handle_call(:get_current_dataset, _from, state) do
    {:reply, state.current_dataset, state}
  end

  @impl true
  def handle_call(:get_current_dataset_counts, _from, state) do
    counts = Map.get(state.dataset_metadata, state.current_dataset, %{})
    {:reply, counts, state}
  end

  @impl true
  def handle_call(:get_available_datasets, _from, state) do
    {:reply, state.available_datasets, state}
  end

  @impl true
  def handle_call({:generate_data, volume}, _from, state) do
    if state.generation_in_progress do
      {:reply, {:error, "Data generation already in progress"}, state}
    else
      # Set flag to true before starting work
      working_state = %{state | generation_in_progress: true}

      case generate_data_internal(volume) do
        :ok ->
          updated_state = %{
            working_state
            | generation_in_progress: false,
              last_generated: DateTime.utc_now(),
              current_dataset: volume
          }

          {:reply, :ok, updated_state}

        {:error, reason} ->
          updated_state = %{working_state | generation_in_progress: false}
          Logger.error("Data generation failed: #{reason}")
          {:reply, {:error, reason}, updated_state}
      end
    end
  end

  @impl true
  def handle_call(:reset, _from, state) do
    case reset_data_internal() do
      :ok ->
        updated_state = %{state | last_generated: nil, current_dataset: nil}
        {:reply, :ok, updated_state}

      {:error, reason} ->
        Logger.error("Data reset failed: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      current_dataset: state.current_dataset,
      available_datasets: state.available_datasets,
      generation_in_progress: state.generation_in_progress
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:generate_foundation_data, _from, state) do
    if state.generation_in_progress do
      {:reply, {:error, "Data generation already in progress"}, state}
    else
      # Use a small volume config just for foundation data
      volume_config = @data_volumes.small

      case generate_foundation_data(volume_config) do
        :ok ->
          {:reply, :ok, state}

        {:error, reason} ->
          Logger.error("Foundation data generation failed: #{reason}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call(:generate_customer_data, _from, state) do
    if state.generation_in_progress do
      {:reply, {:error, "Data generation already in progress"}, state}
    else
      volume_config = @data_volumes.small

      case generate_customer_data(volume_config) do
        :ok ->
          {:reply, :ok, state}

        {:error, reason} ->
          Logger.error("Customer data generation failed: #{reason}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call(:generate_product_data, _from, state) do
    if state.generation_in_progress do
      {:reply, {:error, "Data generation already in progress"}, state}
    else
      volume_config = @data_volumes.small

      case generate_product_data(volume_config) do
        :ok ->
          {:reply, :ok, state}

        {:error, reason} ->
          Logger.error("Product data generation failed: #{reason}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call(:generate_invoice_data, _from, state) do
    if state.generation_in_progress do
      {:reply, {:error, "Data generation already in progress"}, state}
    else
      volume_config = @data_volumes.small

      case generate_invoice_data(volume_config) do
        :ok ->
          {:reply, :ok, state}

        {:error, reason} ->
          Logger.error("Invoice data generation failed: #{reason}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call(:validate_integrity, _from, state) do
    case validate_referential_integrity() do
      {:ok, stats} ->
        {:reply, {:ok, stats}, state}

      {:error, reason} ->
        Logger.error("Data integrity validation failed: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:generate_for_export, volume}, _from, state) do
    case generate_dataset_data(volume) do
      {:ok, dataset_data} ->
        # Prepare data for JSON serialization (handle Decimal, Date, DateTime)
        json_ready_data = prepare_dataset_for_json(dataset_data)
        {:reply, {:ok, json_ready_data}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:load_from_json, file_path}, _from, state) do
    case load_dataset_from_json_file(file_path) do
      {:ok, volume} ->
        updated_state = %{state | current_dataset: volume}
        {:reply, :ok, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private implementation

  defp generate_all_datasets_internal do
    Logger.info("Generating all datasets in parallel...")

    # Temporarily suppress debug logging during generation
    original_level = Logger.level()
    Logger.configure(level: :info)

    try do
      # First, generate foundation data once
      Logger.info("Generating foundation data...")
      EtsTables.ensure_tables_exist()
      EtsTables.clear_all_data()

      # Use small config for foundation
      volume_config = @data_volumes[:small]

      case generate_foundation_data(volume_config) do
        :ok ->
          Logger.info("Foundation data generated successfully")

          # Extract foundation data to share across all datasets
          foundation_data = extract_foundation_data()

          # Generate datasets in parallel using tasks
          tasks =
            for volume <- [:small, :medium, :large, :huge] do
              Task.async(fn ->
                vol_config = @data_volumes[volume]

                Logger.info(
                  "Starting generation of #{volume} dataset (#{vol_config.customers} customers, #{vol_config.products} products, #{vol_config.invoices} invoices)..."
                )

                start_time = System.monotonic_time(:millisecond)

                result = generate_dataset_data_with_foundation(volume, foundation_data)

                case result do
                  {:ok, dataset_data} ->
                    end_time = System.monotonic_time(:millisecond)
                    duration = end_time - start_time

                    # Calculate total entities generated
                    total_entities =
                      dataset_data
                      |> Map.values()
                      |> Enum.map(&length/1)
                      |> Enum.sum()

                    Logger.info(
                      "Completed #{volume} dataset in #{duration}ms - Total entities: #{total_entities}"
                    )

                    {volume, :ok, dataset_data}

                  {:error, reason} ->
                    Logger.error("Failed to generate #{volume} dataset: #{reason}")
                    {volume, {:error, reason}, nil}
                end
              end)
            end

          # Wait for all tasks to complete
          # 15 minutes timeout
          results = Task.await_many(tasks, 900_000)

          # Check if all succeeded
          failed = Enum.filter(results, fn {_volume, status, _data} -> status != :ok end)

          if Enum.empty?(failed) do
            Logger.info("All datasets generated successfully!")

            # Store all datasets in the state
            datasets =
              results
              |> Enum.map(fn {volume, :ok, data} -> {volume, data} end)
              |> Map.new()

            # For multitenancy: Load ALL datasets with their dataset_ids
            Enum.each(datasets, fn {volume, data} ->
              dataset_id = Atom.to_string(volume)
              {:ok, _} = load_dataset_data(data, dataset_id)
              Logger.info("Loaded #{volume} dataset with dataset_id=#{dataset_id}")
            end)

            # Update the process state to store datasets
            send(self(), {:store_datasets, datasets})

            :ok
          else
            failed_volumes = Enum.map(failed, fn {volume, _status, _data} -> volume end)
            {:error, "Failed to generate datasets: #{inspect(failed_volumes)}"}
          end

        {:error, reason} ->
          {:error, "Failed to generate foundation data: #{reason}"}
      end
    after
      # Restore original log level
      Logger.configure(level: original_level)
    end
  rescue
    error ->
      Logger.error("Error during parallel dataset generation: #{Exception.message(error)}")
      {:error, Exception.message(error)}
  end

  defp extract_foundation_data do
    foundation_tables = [:demo_customer_types, :demo_product_categories]

    foundation_tables
    |> Enum.map(fn table_name ->
      data = :ets.tab2list(table_name)
      {table_name, data}
    end)
    |> Map.new()
  end

  defp generate_dataset_data_with_foundation(volume, foundation_data) do
    # Ensure tables exist and clear current data
    EtsTables.ensure_tables_exist()
    EtsTables.clear_all_data()

    # Load foundation data first
    Enum.each(foundation_data, fn {table_name, records} ->
      Enum.each(records, fn record ->
        :ets.insert(table_name, record)
      end)
    end)

    # Generate the rest of the data for this volume
    volume_config = @data_volumes[volume]

    with :ok <- generate_customer_data(volume_config),
         :ok <- generate_product_data(volume_config),
         :ok <- generate_invoice_data(volume_config) do
      # Extract all data from ETS tables
      dataset_data = extract_all_table_data()
      {:ok, dataset_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_dataset_data(volume) do
    # Ensure tables exist and clear current data
    EtsTables.ensure_tables_exist()
    EtsTables.clear_all_data()

    # Generate data for this volume
    case generate_data_internal(volume) do
      :ok ->
        # Extract all data from ETS tables
        dataset_data = extract_all_table_data()
        {:ok, dataset_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_all_table_data do
    table_names = [
      :demo_customers,
      :demo_customer_addresses,
      :demo_customer_types,
      :demo_products,
      :demo_product_categories,
      :demo_inventory,
      :demo_invoices,
      :demo_invoice_line_items
    ]

    table_names
    |> Enum.map(fn table_name ->
      data = :ets.tab2list(table_name)
      {table_name, data}
    end)
    |> Map.new()
  end

  defp prepare_dataset_for_json(dataset_data) do
    # Convert special types (Decimal, Date, DateTime, UUID) to JSON-friendly format
    # Also convert tuples to lists since Jason can't encode tuples
    dataset_data
    |> Enum.map(fn {table_name, records} ->
      prepared_records =
        Enum.map(records, fn {key, data_map} ->
          # Convert the key (which might be a binary UUID) to string
          prepared_key = prepare_value_for_json(key)

          # Convert all values in the data map
          prepared_data =
            data_map
            |> Enum.map(fn {k, v} -> {k, prepare_value_for_json(v)} end)
            |> Enum.into(%{})

          # Convert tuple to list for JSON encoding
          [prepared_key, prepared_data]
        end)

      {table_name, prepared_records}
    end)
    |> Map.new()
  end

  defp prepare_value_for_json(%Decimal{} = decimal),
    do: %{__decimal__: Decimal.to_string(decimal)}

  defp prepare_value_for_json(%Date{} = date), do: %{__date__: Date.to_iso8601(date)}

  defp prepare_value_for_json(%DateTime{} = datetime),
    do: %{__datetime__: DateTime.to_iso8601(datetime)}

  # Convert binary UUIDs to string format
  defp prepare_value_for_json(<<_::128>> = uuid_binary) do
    Ecto.UUID.cast!(uuid_binary)
  end

  defp prepare_value_for_json(value), do: value

  defp load_dataset_data(dataset_data, dataset_id) do
    # For multitenancy: Don't clear all data - datasets coexist with different dataset_id
    # Only clear if we want to reload a specific dataset (future enhancement)

    # Define resource loading order (respecting foreign key dependencies)
    loading_order = [
      {:demo_customer_types, AshReportsDemo.CustomerType},
      {:demo_product_categories, AshReportsDemo.ProductCategory},
      {:demo_customers, AshReportsDemo.Customer},
      {:demo_customer_addresses, AshReportsDemo.CustomerAddress},
      {:demo_products, AshReportsDemo.Product},
      {:demo_inventory, AshReportsDemo.Inventory},
      {:demo_invoices, AshReportsDemo.Invoice},
      {:demo_invoice_line_items, AshReportsDemo.InvoiceLineItem}
    ]

    # Load each resource type in order using Ash API
    result =
      Enum.reduce_while(loading_order, {:ok, []}, fn {table_name, resource}, {:ok, acc} ->
        records = Map.get(dataset_data, table_name, [])

        case load_records_via_ash(resource, records, dataset_id) do
          :ok ->
            count = length(records)
            {:cont, {:ok, [{table_name, count} | acc]}}

          {:error, reason} ->
            {:halt, {:error, "Failed to load #{table_name}: #{inspect(reason)}"}}
        end
      end)

    case result do
      {:ok, stats} ->
        Logger.info(
          "Successfully loaded #{dataset_id} dataset via Ash API: #{inspect(Enum.reverse(stats))}"
        )

        {:ok, dataset_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Load records using Ash.bulk_create for proper struct creation
  defp load_records_via_ash(_resource, [], _dataset_id), do: :ok

  defp load_records_via_ash(resource, records, dataset_id) when is_list(records) do
    count = length(records)
    Logger.debug("Loading #{count} records into #{inspect(resource)} via Ash.bulk_create with dataset_id=#{dataset_id}")

    # Transform tuples {uuid, map} into input maps for Ash
    # Add dataset_id to each record for multitenancy
    input_maps =
      Enum.map(records, fn {uuid_key, data_map} ->
        data_map
        |> Map.put(:id, uuid_key)
        |> Map.put(:dataset_id, dataset_id)
      end)

    # Use Ash.bulk_create for efficient batch creation
    # Use :seed action which accepts all fields including id, dataset_id, and timestamps
    
    result =
      Ash.bulk_create(input_maps, resource, :seed,
        domain: AshReportsDemo.Domain,
        
        return_records?: false,
        return_errors?: true,
        batch_size: 100,
        stop_on_error?: true,
        transaction: :batch
      )

    case result do
      %Ash.BulkResult{status: :success, records: _records} ->
        final_count =
          resource
          |> Ash.read!(domain: AshReportsDemo.Domain)
          |> Enum.count()

        Logger.debug("#{inspect(resource)} now has #{final_count} records for dataset #{dataset_id}")
        :ok

      %Ash.BulkResult{status: :error, errors: errors} ->
        Logger.error("Failed to bulk create #{inspect(resource)}: #{inspect(errors)}")
        {:error, errors}

      other ->
        Logger.error("Unexpected bulk_create result: #{inspect(other)}")
        {:error, "Unexpected result: #{inspect(other)}"}
    end
  end

  defp calculate_dataset_metadata(file_path) do
    with {:ok, json_content} <- File.read(file_path),
         {:ok, json_data} <- Jason.decode(json_content) do
      # Calculate counts without loading into ETS
      counts = %{
        customer_types: length(Map.get(json_data, "demo_customer_types", [])),
        product_categories: length(Map.get(json_data, "demo_product_categories", [])),
        customers: length(Map.get(json_data, "demo_customers", [])),
        addresses: length(Map.get(json_data, "demo_customer_addresses", [])),
        products: length(Map.get(json_data, "demo_products", [])),
        inventory: length(Map.get(json_data, "demo_inventory", [])),
        invoices: length(Map.get(json_data, "demo_invoices", [])),
        line_items: length(Map.get(json_data, "demo_invoice_line_items", []))
      }

      {:ok, counts}
    else
      {:error, :enoent} ->
        {:error, "File not found: #{file_path}"}

      {:error, %Jason.DecodeError{} = error} ->
        {:error, "Failed to parse JSON: #{Exception.message(error)}"}

      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  defp load_dataset_from_json_file(file_path) do
    with {:ok, volume} <- extract_volume_from_path(file_path),
         {:ok, json_content} <- File.read(file_path),
         {:ok, json_data} <- Jason.decode(json_content),
         {:ok, dataset_data} <- convert_json_to_dataset(json_data),
         # Pass dataset_id as string for multitenancy attribute
         dataset_id = Atom.to_string(volume),
         {:ok, _} <- load_dataset_data(dataset_data, dataset_id) do
      Logger.info("Loaded #{volume} dataset from #{file_path} with dataset_id=#{dataset_id}")

      {:ok, volume}
    else
      {:error, :enoent} ->
        {:error, "File not found: #{file_path}"}

      {:error, %Jason.DecodeError{} = error} ->
        {:error, "Failed to parse JSON: #{Exception.message(error)}"}

      {:error, reason} ->
        {:error, "Failed to load dataset: #{inspect(reason)}"}
    end
  end

  defp convert_json_to_dataset(json_data) do
    try do
      # Convert string keys to atoms and reconstruct the data structure
      dataset_data =
        json_data
        |> Enum.map(fn {table_name_str, records} ->
          # Safe to use String.to_atom here as the data comes from our own generated JSON files
          table_name = String.to_atom(table_name_str)

          converted_records =
            Enum.map(records, fn record_list ->
              # ETS stores records as tuples: {key, map_of_data}
              # The record_list from JSON is [key_map, data_map]
              [key_map | rest] = record_list
              data_map = List.first(rest, %{})

              # Extract the ID from the key map and convert to binary
              key_value = Map.get(key_map, "id")
              converted_key = convert_value(key_value)

              # Convert string keys in the data map to atoms
              # Safe to use String.to_atom here as these are field names from our schema
              converted_data =
                data_map
                |> Enum.map(fn {k, v} ->
                  {String.to_atom(k), convert_value(v)}
                end)
                |> Enum.into(%{})

              {converted_key, converted_data}
            end)

          {table_name, converted_records}
        end)
        |> Map.new()

      {:ok, dataset_data}
    rescue
      e ->
        {:error, "Failed to convert JSON data: #{Exception.message(e)}"}
    end
  end

  defp convert_value(%{"__decimal__" => decimal_str}), do: Decimal.new(decimal_str)
  defp convert_value(%{"__date__" => date_str}), do: Date.from_iso8601!(date_str)

  defp convert_value(%{"__datetime__" => datetime_str}) do
    {:ok, datetime, _offset} = DateTime.from_iso8601(datetime_str)
    datetime
  end

  # Convert string UUIDs back to binary format
  defp convert_value(value) when is_binary(value) do
    # Check if it looks like a UUID (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
    case String.match?(value, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) do
      true ->
        case Ecto.UUID.dump(value) do
          {:ok, binary} -> binary
          _ -> value
        end

      false ->
        value
    end
  end

  defp convert_value(value), do: value

  defp extract_volume_from_path(file_path) do
    case Path.basename(file_path, ".json") do
      "small" -> {:ok, :small}
      "medium" -> {:ok, :medium}
      "large" -> {:ok, :large}
      "huge" -> {:ok, :huge}
      _ -> {:error, "Unknown volume in filename"}
    end
  end

  # Private implementation

  defp generate_data_internal(volume) do
    volume_config = Map.get(@data_volumes, volume)

    if volume_config do
      Logger.info(
        "Generating #{volume} dataset (#{volume_config.customers} customers, #{volume_config.products} products, #{volume_config.invoices} invoices)..."
      )

      # Temporarily suppress debug logging during generation
      original_level = Logger.level()
      Logger.configure(level: :info)

      try do
        # Start transaction: clear existing data and track checkpoint
        EtsTables.ensure_tables_exist()
        :ok = EtsTables.clear_all_data()
        generation_start = System.monotonic_time(:millisecond)

        result =
          with :ok <- generate_foundation_data(volume_config),
               :ok <- generate_customer_data(volume_config),
               :ok <- generate_product_data(volume_config),
               :ok <- generate_invoice_data(volume_config),
               {:ok, integrity_stats} <- validate_referential_integrity() do
            generation_time = System.monotonic_time(:millisecond) - generation_start

            # Calculate total entities generated
            total_entities = integrity_stats |> Map.values() |> Enum.sum()

            Logger.info(
              "Completed #{volume} dataset in #{generation_time}ms - Total entities: #{total_entities} - #{inspect(integrity_stats)}"
            )

            :ok
          else
            {:error, reason} ->
              Logger.error("Data generation failed: #{reason}")
              rollback_transaction()
              {:error, reason}
          end

        result
      after
        # Restore original log level
        Logger.configure(level: original_level)
      end
    else
      {:error,
       "Unknown volume: #{volume}. Available: #{Map.keys(@data_volumes) |> Enum.join(", ")}"}
    end
  rescue
    error ->
      Logger.error("Unexpected error during data generation: #{Exception.message(error)}")
      rollback_transaction()
      {:error, Exception.message(error)}
  end

  defp rollback_transaction do
    reset_data_internal()
  end

  # Phase 7.3: Data Generation Functions

  defp generate_foundation_data(_volume_config) do
    with {:ok, _customer_types} <- create_customer_types(),
         {:ok, _product_categories} <- create_product_categories() do
      :ok
    else
      {:error, reason} -> {:error, "Foundation data generation failed: #{reason}"}
    end
  end

  defp create_customer_types do
    customer_type_specs = [
      %{
        name: "Bronze",
        description: "Basic customer tier",
        discount_percentage: Decimal.new("0"),
        active: true,
        priority_level: 1
      },
      %{
        name: "Silver",
        description: "Standard customer tier",
        discount_percentage: Decimal.new("5"),
        active: true,
        priority_level: 2
      },
      %{
        name: "Gold",
        description: "Premium customer tier",
        discount_percentage: Decimal.new("10"),
        active: true,
        priority_level: 3
      },
      %{
        name: "Platinum",
        description: "Elite customer tier",
        discount_percentage: Decimal.new("15"),
        active: true,
        priority_level: 4
      }
    ]

    results =
      for type_spec <- customer_type_specs do
        create_or_find_customer_type(type_spec)
      end

    valid_types = Enum.reject(results, &is_nil/1)

    if length(valid_types) >= 4 do
      {:ok, valid_types}
    else
      {:error, "Failed to ensure all customer types exist"}
    end
  end

  defp create_product_categories do
    category_specs = [
      %{
        name: "Electronics",
        description: "Electronic devices and accessories",
        sort_order: 1,
        active: true
      },
      %{name: "Clothing", description: "Apparel and accessories", sort_order: 2, active: true},
      %{
        name: "Home & Garden",
        description: "Home improvement and gardening",
        sort_order: 3,
        active: true
      },
      %{
        name: "Books",
        description: "Books and educational materials",
        sort_order: 4,
        active: true
      },
      %{name: "Sports", description: "Sports and outdoor equipment", sort_order: 5, active: true}
    ]

    results =
      for category_spec <- category_specs do
        create_or_find_product_category(category_spec)
      end

    valid_categories = Enum.reject(results, &is_nil/1)

    if length(valid_categories) >= 5 do
      {:ok, valid_categories}
    else
      {:error, "Failed to ensure all product categories exist"}
    end
  end

  defp generate_customer_data(volume_config) do
    customer_count = volume_config.customers
    address_range = volume_config.addresses_per_customer

    with {:ok, customer_types} <- get_available_customer_types(),
         {:ok, customers} <- create_customers_batch(customer_types, customer_count),
         {:ok, _addresses} <- create_addresses_for_customers(customers, address_range) do
      :ok
    else
      {:error, reason} -> {:error, "Customer data generation failed: #{reason}"}
    end
  end

  defp generate_product_data(volume_config) do
    product_count = volume_config.products

    with {:ok, categories} <- get_available_product_categories(),
         {:ok, products} <- create_products_batch(categories, product_count),
         {:ok, _inventory} <- create_inventory_for_products(products) do
      :ok
    else
      {:error, reason} -> {:error, "Product data generation failed: #{reason}"}
    end
  end

  defp get_available_customer_types do
    case Ash.read(CustomerType, domain: Domain) do
      {:ok, []} -> {:error, "No customer types available - run foundation data first"}
      {:ok, customer_types} -> {:ok, customer_types}
      {:error, error} -> {:error, "Failed to load customer types: #{inspect(error)}"}
    end
  end

  defp get_available_product_categories do
    case Ash.read(ProductCategory, domain: Domain) do
      {:ok, []} -> {:error, "No product categories available - run foundation data first"}
      {:ok, categories} -> {:ok, categories}
      {:error, error} -> {:error, "Failed to load product categories: #{inspect(error)}"}
    end
  end

  defp create_products_batch(categories, product_count) do
    products =
      1..product_count
      |> Enum.map(fn i ->
        if rem(i, 1000) == 0 do
          Logger.info("  Generated #{i}/#{product_count} products...")
        end

        category = Enum.random(categories)

        # Generate realistic pricing with proper margins
        # $10-$510
        cost = Decimal.new("#{:rand.uniform(500) + 10}")
        # 1.2x to 2.2x markup
        margin_multiplier = 1.2 + :rand.uniform(100) / 100
        price = Decimal.mult(cost, Decimal.new("#{margin_multiplier}"))

        product_attrs = %{
          name: Faker.Commerce.product_name(),
          sku: generate_unique_sku(i),
          description: Faker.Lorem.sentence(10),
          price: price,
          cost: cost,
          # 0.1 to 10.0 lbs
          weight: Decimal.new("#{:rand.uniform(100) / 10}"),
          category_id: category.id,
          # 75% active
          active: Enum.random([true, true, true, false])
        }

        case Ash.create(Product, product_attrs, domain: Domain) do
          {:ok, product} -> product
          {:error, _error} -> nil
        end
      end)

    valid_products = Enum.reject(products, &is_nil/1)
    failed_count = product_count - length(valid_products)

    if failed_count > 0 do
      Logger.warning("Failed to create #{failed_count}/#{product_count} products")
    end

    if length(valid_products) > 0 do
      {:ok, valid_products}
    else
      {:error, "Failed to create any products"}
    end
  end

  defp create_inventory_for_products(products) do
    inventory_records =
      for product <- products do
        current_stock = :rand.uniform(1000)
        # Ensure reserved_stock never exceeds current_stock
        reserved_stock = :rand.uniform(min(50, current_stock))

        inventory_attrs = %{
          product_id: product.id,
          current_stock: current_stock,
          reserved_stock: reserved_stock,
          # 10-50
          reorder_point: 10 + :rand.uniform(40),
          # 50-250
          reorder_quantity: 50 + :rand.uniform(200),
          location: Enum.random(["Main Warehouse", "East Coast", "West Coast", "Central"]),
          # Within last 90 days
          last_received_date: Faker.Date.backward(:rand.uniform(90)),
          last_received_quantity: 25 + :rand.uniform(200)
        }

        case Ash.create(Inventory, inventory_attrs, domain: Domain) do
          {:ok, inventory} -> inventory
          {:error, _error} -> nil
        end
      end

    valid_inventory = Enum.reject(inventory_records, &is_nil/1)
    {:ok, valid_inventory}
  end

  defp generate_invoice_data(volume_config) do
    with {:ok, customers} <- Ash.read(Customer, domain: Domain),
         {:ok, products} <- Ash.read(Product, domain: Domain),
         :ok <- validate_invoice_prerequisites(customers, products) do
      create_invoices_batch(customers, products, volume_config)
    else
      {:error, reason} -> {:error, "Failed to load customers/products: #{inspect(reason)}"}
    end
  rescue
    error ->
      {:error, "Invoice data generation failed: #{Exception.message(error)}"}
  end

  defp create_line_items_for_invoice(invoice, products, volume_config) do
    line_item_range = volume_config.line_items_per_invoice
    line_item_count = Enum.random(line_item_range)

    results =
      for _j <- 1..line_item_count do
        product = Enum.random(products)
        # 1-20 units
        quantity = Decimal.new("#{1 + :rand.uniform(20)}")

        # Use product price with potential discount
        unit_price =
          if :rand.uniform(4) == 1 do
            # 25% chance of discount
            discount = Decimal.mult(product.price, Decimal.new("#{:rand.uniform(20) / 100}"))
            Decimal.sub(product.price, discount)
          else
            product.price
          end

        line_total = Decimal.mult(quantity, unit_price)

        line_item_attrs = %{
          invoice_id: invoice.id,
          product_id: product.id,
          quantity: quantity,
          unit_price: unit_price,
          line_total: line_total,
          description: if(:rand.uniform(3) == 1, do: Faker.Lorem.sentence(5), else: "")
        }

        case Ash.create(InvoiceLineItem, line_item_attrs, domain: Domain) do
          {:ok, _line_item} -> {:ok, line_total}
          {:error, _error} -> {:error, line_total}
        end
      end

    # Calculate subtotal from successful line items
    subtotal =
      results
      |> Enum.filter(fn {status, _} -> status == :ok end)
      |> Enum.reduce(Decimal.new("0.00"), fn {:ok, line_total}, acc ->
        Decimal.add(acc, line_total)
      end)

    error_count = Enum.count(results, fn {status, _} -> status == :error end)

    if error_count == 0 do
      {:ok, subtotal}
    else
      {:error, "#{error_count} line items failed to create"}
    end
  end

  defp reset_data_internal do
    # Ensure tables exist and clear all ETS data
    EtsTables.ensure_tables_exist()
    EtsTables.clear_all_data()
  rescue
    error ->
      {:error, Exception.message(error)}
  end

  # Referential integrity validation functions

  defp validate_referential_integrity do
    with {:ok, customer_types} <- validate_customer_types_exist(),
         {:ok, product_categories} <- validate_product_categories_exist(),
         {:ok, customers} <- validate_customers_have_valid_types(),
         {:ok, products} <- validate_products_have_valid_categories(),
         {:ok, addresses} <- validate_addresses_have_valid_customers(),
         {:ok, inventory} <- validate_inventory_has_valid_products(),
         {:ok, invoices} <- validate_invoices_have_valid_customers(),
         {:ok, line_items} <- validate_line_items_have_valid_references() do
      {:ok,
       %{
         customer_types: length(customer_types),
         product_categories: length(product_categories),
         customers: length(customers),
         products: length(products),
         addresses: length(addresses),
         inventory: length(inventory),
         invoices: length(invoices),
         line_items: length(line_items)
       }}
    else
      {:error, reason} -> {:error, "Referential integrity validation failed: #{reason}"}
    end
  end

  defp validate_customer_types_exist do
    case Ash.read(CustomerType, domain: Domain) do
      {:ok, types} when length(types) >= 4 ->
        {:ok, types}

      {:ok, types} ->
        {:error, "Insufficient customer types: #{length(types)}, expected at least 4"}

      {:error, error} ->
        {:error, "Could not read customer types: #{inspect(error)}"}
    end
  end

  defp validate_product_categories_exist do
    case Ash.read(ProductCategory, domain: Domain) do
      {:ok, categories} when length(categories) >= 5 ->
        {:ok, categories}

      {:ok, categories} ->
        {:error, "Insufficient product categories: #{length(categories)}, expected at least 5"}

      {:error, error} ->
        {:error, "Could not read product categories: #{inspect(error)}"}
    end
  end

  defp validate_customers_have_valid_types do
    with {:ok, customers} <- Ash.read(Customer, domain: Domain),
         {:ok, customer_types} <- Ash.read(CustomerType, domain: Domain) do
      customer_type_ids = MapSet.new(customer_types, & &1.id)

      invalid_customers =
        Enum.filter(customers, fn customer ->
          not MapSet.member?(customer_type_ids, customer.customer_type_id)
        end)

      if Enum.empty?(invalid_customers) do
        {:ok, customers}
      else
        {:error,
         "#{length(invalid_customers)} customers have invalid customer_type_id references"}
      end
    else
      {:error, error} ->
        {:error, "Could not validate customer-type relationships: #{inspect(error)}"}
    end
  end

  defp validate_products_have_valid_categories do
    with {:ok, products} <- Ash.read(Product, domain: Domain),
         {:ok, categories} <- Ash.read(ProductCategory, domain: Domain) do
      category_ids = MapSet.new(categories, & &1.id)

      invalid_products =
        Enum.filter(products, fn product ->
          not MapSet.member?(category_ids, product.category_id)
        end)

      if Enum.empty?(invalid_products) do
        {:ok, products}
      else
        {:error, "#{length(invalid_products)} products have invalid category_id references"}
      end
    else
      {:error, error} ->
        {:error, "Could not validate product-category relationships: #{inspect(error)}"}
    end
  end

  defp validate_addresses_have_valid_customers do
    with {:ok, addresses} <- Ash.read(CustomerAddress, domain: Domain),
         {:ok, customers} <- Ash.read(Customer, domain: Domain) do
      customer_ids = MapSet.new(customers, & &1.id)

      invalid_addresses =
        Enum.filter(addresses, fn address ->
          not MapSet.member?(customer_ids, address.customer_id)
        end)

      if Enum.empty?(invalid_addresses) do
        {:ok, addresses}
      else
        {:error, "#{length(invalid_addresses)} addresses have invalid customer_id references"}
      end
    else
      {:error, error} ->
        {:error, "Could not validate address-customer relationships: #{inspect(error)}"}
    end
  end

  defp validate_inventory_has_valid_products do
    with {:ok, inventory} <- Ash.read(Inventory, domain: Domain),
         {:ok, products} <- Ash.read(Product, domain: Domain) do
      product_ids = MapSet.new(products, & &1.id)

      invalid_inventory =
        Enum.filter(inventory, fn inv ->
          not MapSet.member?(product_ids, inv.product_id)
        end)

      if Enum.empty?(invalid_inventory) do
        {:ok, inventory}
      else
        {:error,
         "#{length(invalid_inventory)} inventory records have invalid product_id references"}
      end
    else
      {:error, error} ->
        {:error, "Could not validate inventory-product relationships: #{inspect(error)}"}
    end
  end

  defp validate_invoices_have_valid_customers do
    with {:ok, invoices} <- Ash.read(Invoice, domain: Domain),
         {:ok, customers} <- Ash.read(Customer, domain: Domain) do
      customer_ids = MapSet.new(customers, & &1.id)

      invalid_invoices =
        Enum.filter(invoices, fn invoice ->
          not MapSet.member?(customer_ids, invoice.customer_id)
        end)

      if Enum.empty?(invalid_invoices) do
        {:ok, invoices}
      else
        {:error, "#{length(invalid_invoices)} invoices have invalid customer_id references"}
      end
    else
      {:error, error} ->
        {:error, "Could not validate invoice-customer relationships: #{inspect(error)}"}
    end
  end

  defp validate_line_items_have_valid_references do
    with {:ok, line_items} <- Ash.read(InvoiceLineItem, domain: Domain),
         {:ok, invoices} <- Ash.read(Invoice, domain: Domain),
         {:ok, products} <- Ash.read(Product, domain: Domain) do
      invoice_ids = MapSet.new(invoices, & &1.id)
      product_ids = MapSet.new(products, & &1.id)

      invalid_line_items =
        Enum.filter(line_items, fn line_item ->
          not MapSet.member?(invoice_ids, line_item.invoice_id) or
            not MapSet.member?(product_ids, line_item.product_id)
        end)

      if Enum.empty?(invalid_line_items) do
        {:ok, line_items}
      else
        {:error,
         "#{length(invalid_line_items)} line items have invalid invoice_id or product_id references"}
      end
    else
      {:error, error} -> {:error, "Could not validate line item relationships: #{inspect(error)}"}
    end
  end

  # Helper functions for enhanced data generation

  defp create_customers_batch(customer_types, customer_count) do
    customers =
      1..customer_count
      |> Enum.map(fn i ->
        if rem(i, 1000) == 0 do
          Logger.info("  Generated #{i}/#{customer_count} customers...")
        end

        customer_type = Enum.random(customer_types)

        customer_attrs = %{
          name: Faker.Person.name(),
          email: generate_unique_email(i),
          phone: Faker.Phone.EnUs.phone(),
          status: weighted_random_status(),
          credit_limit: generate_realistic_credit_limit(customer_type),
          notes: if(:rand.uniform(3) == 1, do: Faker.Lorem.sentence(), else: ""),
          customer_type_id: customer_type.id
        }

        case Ash.create(Customer, customer_attrs, domain: Domain) do
          {:ok, customer} -> customer
          {:error, _error} -> nil
        end
      end)

    valid_customers = Enum.reject(customers, &is_nil/1)
    failed_count = customer_count - length(valid_customers)

    if failed_count > 0 do
      Logger.warning("Failed to create #{failed_count}/#{customer_count} customers")
    end

    if length(valid_customers) > 0 do
      {:ok, valid_customers}
    else
      {:error, "Failed to create any customers"}
    end
  end

  defp create_addresses_for_customers(customers, address_range) do
    customer_count = length(customers)

    all_addresses =
      customers
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {customer, idx} ->
        if rem(idx, 1000) == 0 do
          Logger.info("  Generated addresses for #{idx}/#{customer_count} customers...")
        end

        address_count = Enum.random(address_range)

        for i <- 1..address_count do
          address_attrs = %{
            customer_id: customer.id,
            address_type: determine_address_type(i),
            street: Faker.Address.street_address(),
            city: Faker.Address.city(),
            state: Faker.Address.state(),
            postal_code: Faker.Address.zip_code(),
            country: "United States",
            primary: i == 1
          }

          case Ash.create(CustomerAddress, address_attrs, domain: Domain) do
            {:ok, address} -> address
            {:error, _error} -> nil
          end
        end
      end)

    valid_addresses = Enum.reject(all_addresses, &is_nil/1)

    # Update customer region_name based on primary address
    update_customer_regions(customers)

    {:ok, valid_addresses}
  end

  defp update_customer_regions(customers) do
    Logger.info("  Updating customer region classifications...")

    customers
    |> Enum.each(fn customer ->
      # Load customer with addresses to get primary address
      case Ash.get(Customer, customer.id, load: [:addresses], domain: Domain) do
        {:ok, loaded_customer} ->
          # Find primary address
          primary_address =
            loaded_customer.addresses
            |> Enum.find(&(&1.primary == true))

          if primary_address do
            region_name = classify_state_to_region(primary_address.state)

            # Update customer with region_name
            loaded_customer
            |> Ash.Changeset.for_update(:update, %{region_name: region_name})
            |> Ash.update!(domain: Domain)
          end

        {:error, _} ->
          Logger.warning("Could not load customer #{customer.id} to update region")
      end
    end)
  end

  defp classify_state_to_region(state) do
    cond do
      state in ["CA", "California", "OR", "Oregon", "WA", "Washington", "NV", "Nevada",
                "AZ", "Arizona", "UT", "Utah", "CO", "Colorado", "ID", "Idaho",
                "MT", "Montana", "WY", "Wyoming", "NM", "New Mexico", "AK", "Alaska", "HI", "Hawaii"] ->
        "West"

      state in ["ME", "Maine", "NH", "New Hampshire", "VT", "Vermont", "MA", "Massachusetts",
                "RI", "Rhode Island", "CT", "Connecticut", "NY", "New York", "NJ", "New Jersey", "PA", "Pennsylvania"] ->
        "Northeast"

      state in ["MD", "Maryland", "DE", "Delaware", "VA", "Virginia", "WV", "West Virginia",
                "NC", "North Carolina", "SC", "South Carolina", "GA", "Georgia", "FL", "Florida",
                "AL", "Alabama", "MS", "Mississippi", "TN", "Tennessee", "KY", "Kentucky"] ->
        "Southeast"

      state in ["OH", "Ohio", "IN", "Indiana", "IL", "Illinois", "MI", "Michigan",
                "WI", "Wisconsin", "MN", "Minnesota", "IA", "Iowa", "MO", "Missouri",
                "ND", "North Dakota", "SD", "South Dakota", "NE", "Nebraska", "KS", "Kansas"] ->
        "Midwest"

      state in ["TX", "Texas", "OK", "Oklahoma", "AR", "Arkansas", "LA", "Louisiana"] ->
        "Southwest"

      true ->
        "Unknown"
    end
  end

  # Helper functions for realistic data generation
  defp generate_unique_email(index) do
    base_email = Faker.Internet.email()
    "demo#{index}.#{base_email}"
  end

  defp weighted_random_status do
    # 70% active, 20% inactive, 10% suspended
    case :rand.uniform(10) do
      n when n <= 7 -> :active
      n when n <= 9 -> :inactive
      _ -> :suspended
    end
  end

  defp generate_realistic_credit_limit(customer_type) do
    base_amount = Decimal.new("5000")
    # Use priority_level to determine multiplier (higher priority = higher credit limit)
    multiplier = Decimal.new("#{customer_type.priority_level}")
    # $0-$5000 variation
    variation = Decimal.new("#{:rand.uniform(50) * 100}")

    base_amount
    |> Decimal.mult(multiplier)
    |> Decimal.add(variation)
  end

  defp determine_address_type(1), do: :billing
  defp determine_address_type(_), do: Enum.random([:shipping, :mailing])

  defp generate_unique_sku(index) do
    "SKU-#{String.pad_leading(Integer.to_string(index), 6, "0")}-#{:rand.uniform(999)}"
  end

  defp finalize_invoice_with_line_items(invoice, products, volume_config) do
    case create_line_items_for_invoice(invoice, products, volume_config) do
      {:ok, subtotal} ->
        update_invoice_totals(invoice, subtotal)

      {:error, _reason} ->
        :error
    end
  end

  defp update_invoice_totals(invoice, subtotal) do
    tax_amount = Decimal.mult(subtotal, Decimal.div(invoice.tax_rate, 100))
    total = Decimal.add(subtotal, tax_amount)

    case Ash.update(
           invoice,
           %{
             subtotal: subtotal,
             tax_amount: tax_amount,
             total: total
           },
           domain: Domain
         ) do
      {:ok, _updated_invoice} ->
        :ok

      {:error, _error} ->
        :error
    end
  end

  defp validate_invoice_prerequisites(customers, products) do
    if Enum.empty?(customers) or Enum.empty?(products) do
      {:error, "Cannot generate invoices without customers and products"}
    else
      :ok
    end
  end

  defp create_invoices_batch(customers, products, volume_config) do
    invoice_count = volume_config.invoices

    results =
      1..invoice_count
      |> Enum.map(fn i ->
        if rem(i, 1000) == 0 do
          Logger.info("  Generated #{i}/#{invoice_count} invoices...")
        end

        create_single_invoice(customers, products, volume_config, i)
      end)

    evaluate_invoice_creation_results(results, invoice_count)
  end

  defp create_single_invoice(customers, products, volume_config, index) do
    customer = Enum.random(customers)
    invoice_attrs = build_invoice_attributes(customer, index)

    case Ash.create(Invoice, invoice_attrs, domain: Domain) do
      {:ok, invoice} ->
        finalize_invoice_with_line_items(invoice, products, volume_config)

      {:error, _error} ->
        :error
    end
  end

  defp build_invoice_attributes(customer, index) do
    invoice_date = Faker.Date.backward(:rand.uniform(365))
    due_date = Date.add(invoice_date, 30)

    %{
      customer_id: customer.id,
      invoice_number: generate_invoice_number(invoice_date, index),
      date: invoice_date,
      due_date: due_date,
      status: Enum.random([:draft, :sent, :sent, :paid, :overdue]),
      tax_rate: Decimal.new("8.25"),
      payment_terms: Enum.random(["Net 30", "Net 15", "Due on Receipt", "Net 45"]),
      notes: if(:rand.uniform(3) == 1, do: Faker.Lorem.sentence(), else: "")
    }
  end

  defp generate_invoice_number(invoice_date, index) do
    date_string = Date.to_string(invoice_date) |> String.replace("-", "")
    index_string = String.pad_leading(Integer.to_string(index), 4, "0")
    "INV-#{date_string}-#{index_string}"
  end

  defp evaluate_invoice_creation_results(results, invoice_count) do
    error_count = Enum.count(results, &(&1 == :error))

    if error_count < invoice_count / 2 do
      :ok
    else
      {:error, "Too many invoice creation failures: #{error_count}/#{invoice_count}"}
    end
  end

  defp create_or_find_product_category(category_spec) do
    case Ash.read(ProductCategory, domain: Domain) do
      {:ok, categories} ->
        handle_product_category_lookup(categories, category_spec)

      {:error, _error} ->
        nil
    end
  end

  defp handle_product_category_lookup(categories, category_spec) do
    existing = Enum.find(categories, &(&1.name == category_spec.name))

    if existing do
      existing
    else
      create_new_product_category(category_spec)
    end
  end

  defp create_new_product_category(category_spec) do
    case Ash.create(ProductCategory, category_spec, domain: Domain) do
      {:ok, category} ->
        category

      {:error, _error} ->
        nil
    end
  end

  defp create_or_find_customer_type(type_spec) do
    case Ash.read(CustomerType, domain: Domain) do
      {:ok, types} ->
        handle_customer_type_lookup(types, type_spec)

      {:error, _error} ->
        nil
    end
  end

  defp handle_customer_type_lookup(types, type_spec) do
    existing = Enum.find(types, &(&1.name == type_spec.name))

    if existing do
      existing
    else
      create_new_customer_type(type_spec)
    end
  end

  defp create_new_customer_type(type_spec) do
    case Ash.create(CustomerType, type_spec, domain: Domain) do
      {:ok, customer_type} ->
        customer_type

      {:error, _error} ->
        nil
    end
  end
end
