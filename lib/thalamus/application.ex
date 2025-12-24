defmodule Thalamus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    print_banner()

    children = [
      ThalamusWeb.Telemetry,
      Thalamus.Repo,
      {DNSCluster, query: Application.get_env(:thalamus, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Thalamus.PubSub},
      # Start a worker by calling: Thalamus.Worker.start_link(arg)
      # {Thalamus.Worker, arg},
      # Start to serve requests, typically the last entry
      ThalamusWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Thalamus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ThalamusWeb.Endpoint.config_change(changed, removed)
    :ok
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
