defmodule AshReportsDemoWeb.PdfStore do
  @moduledoc """
  Temporary storage for generated PDF files using ETS.

  PDFs are stored with a UUID key and automatically expire after 1 hour.
  """

  use GenServer

  @table_name :pdf_storage
  @cleanup_interval :timer.minutes(5)
  @pdf_ttl :timer.hours(1)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Store a PDF binary and return a unique ID.
  """
  def store_pdf(pdf_binary, metadata \\ %{}) when is_binary(pdf_binary) do
    pdf_id = Ecto.UUID.generate()
    expires_at = System.system_time(:millisecond) + @pdf_ttl

    entry = %{
      id: pdf_id,
      content: pdf_binary,
      metadata: metadata,
      expires_at: expires_at,
      size_bytes: byte_size(pdf_binary)
    }

    :ets.insert(@table_name, {pdf_id, entry})
    {:ok, pdf_id}
  end

  @doc """
  Retrieve a PDF by ID.
  """
  def get_pdf(pdf_id) do
    case :ets.lookup(@table_name, pdf_id) do
      [{^pdf_id, entry}] ->
        if entry.expires_at > System.system_time(:millisecond) do
          {:ok, entry}
        else
          :ets.delete(@table_name, pdf_id)
          {:error, :expired}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Delete a PDF by ID.
  """
  def delete_pdf(pdf_id) do
    :ets.delete(@table_name, pdf_id)
    :ok
  end

  @impl true
  def init(_) do
    :ets.new(@table_name, [:named_table, :public, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_pdfs()
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired_pdfs do
    now = System.system_time(:millisecond)

    @table_name
    |> :ets.tab2list()
    |> Enum.each(fn {pdf_id, entry} ->
      if entry.expires_at <= now do
        :ets.delete(@table_name, pdf_id)
      end
    end)
  end
end
