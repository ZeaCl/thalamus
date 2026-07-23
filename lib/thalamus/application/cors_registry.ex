defmodule Thalamus.CORSRegistry do
  use GenServer
  require Logger

  @table_name :cors_registry

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def add(origin) when is_binary(origin) do
    :ets.insert(@table_name, {origin, true})
    :ok
  end

  def member?(origin) when is_binary(origin) do
    case :ets.lookup(@table_name, origin) do
      [{^origin, true}] -> true
      _ -> false
    end
  end

  def rebuild_from_clients do
    GenServer.cast(__MODULE__, :rebuild_from_clients)
  end

  # GenServer Callbacks

  @impl true
  def init(_state) do
    # Create ETS table with read_concurrency: true for fast concurrent reads
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])

    # Send a message to ourselves to load initial data asynchronously
    send(self(), :load_initial_data)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:load_initial_data, state) do
    do_rebuild()
    {:noreply, state}
  end

  @impl true
  def handle_cast(:rebuild_from_clients, state) do
    do_rebuild()
    {:noreply, state}
  end

  defp do_rebuild do
    origins = load_origins_from_db()

    :ets.delete_all_objects(@table_name)

    objects = Enum.map(origins, fn origin -> {origin, true} end)
    :ets.insert(@table_name, objects)

    Logger.info("CORSRegistry rebuilt with #{length(origins)} origins")
  end

  defp load_origins_from_db do
    import Ecto.Query
    alias Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema
    alias Thalamus.Repo

    Repo.all(from c in OAuth2ClientSchema, where: c.is_active == true)
    |> Enum.flat_map(&(&1.redirect_uris || []))
    |> Enum.map(&extract_origin/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp extract_origin(uri_str) do
    uri = URI.parse(uri_str)
    port = if uri.port && uri.port not in [80, 443], do: ":#{uri.port}", else: ""
    "#{uri.scheme}://#{uri.host}#{port}"
  rescue
    _ -> nil
  end
end
