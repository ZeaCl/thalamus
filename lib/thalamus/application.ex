defmodule Thalamus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    if not is_test?(), do: print_banner()

    children = [
      ThalamusWeb.Telemetry,
      Thalamus.Repo,
      Thalamus.Vault,
      {DNSCluster, query: Application.get_env(:thalamus, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Thalamus.PubSub},
      # Start a worker by calling: Thalamus.Worker.start_link(arg)
      # {Thalamus.Worker, arg},
      # Start to serve requests, typically the last entry
      ThalamusWeb.Endpoint,
      Thalamus.CORSRegistry
    ]

    # Add Redis cache adapter if configured
    children = maybe_add_redis_cache(children)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Thalamus.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Task.start(fn ->
          Thalamus.CORSRegistry.rebuild_from_clients()
        end)

        {:ok, pid}

      error ->
        error
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ThalamusWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_add_redis_cache(children) do
    case Application.get_env(:thalamus, :redis_adapter, :mock) do
      :redix ->
        # Add Redis cache adapter to supervision tree
        [Thalamus.Infrastructure.Adapters.RedisCacheAdapter | children]

      :mock ->
        # Use mock adapter, no supervisor needed
        children
    end
  end

  defp is_test? do
    # Mix is not available in production releases, use System.get_env as fallback
    if Code.ensure_loaded?(Mix) do
      Mix.env() == :test
    else
      System.get_env("MIX_ENV") == "test"
    end
  end

  defp print_banner do
    IO.puts("")
    IO.puts("╔═══════════════════════════════════════════════════════════════════════════╗")
    IO.puts("║                                                                           ║")
    IO.puts("║  ████████╗██╗░░██╗░█████╗░██╗░░░░░░█████╗░███╗░░░███╗██╗░░░██╗░██████╗  ║")
    IO.puts("║  ╚══██╔══╝██║░░██║██╔══██╗██║░░░░░██╔══██╗████╗░████║██║░░░██║██╔════╝  ║")
    IO.puts("║  ░░░██║░░░███████║███████║██║░░░░░███████║██╔████╔██║██║░░░██║╚█████╗░  ║")
    IO.puts("║  ░░░██║░░░██╔══██║██╔══██║██║░░░░░██╔══██║██║╚██╔╝██║██║░░░██║░╚═══██╗  ║")
    IO.puts("║  ░░░██║░░░██║░░██║██║░░██║███████╗██║░░██║██║░╚═╝░██║╚██████╔╝██████╔╝  ║")
    IO.puts("║  ░░░╚═╝░░░╚═╝░░╚═╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░░░░╚═╝░╚═════╝░╚═════╝░  ║")
    IO.puts("║                                                                           ║")
    IO.puts("║              OAuth2 & Identity Provider v1.0.0                           ║")
    IO.puts("║                Secure Authentication Core                                ║")
    IO.puts("╚═══════════════════════════════════════════════════════════════════════════╝")
    IO.puts("")
  end
end
