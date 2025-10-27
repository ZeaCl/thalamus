defmodule ThalamusWeb.API.HealthController do
  @moduledoc """
  Health Check API Controller.

  Provides system health and status information for monitoring
  and load balancing purposes.

  SOLID Principles Applied:
  - Single Responsibility: Only handles health check requests
  """

  use ThalamusWeb, :controller

  alias Thalamus.Repo

  @doc """
  GET /api/public/health

  Returns system health status.

  ## Response

  200 OK:
  {
    "status": "ok",
    "version": "1.0.0",
    "timestamp": "2025-10-26T10:30:00Z",
    "checks": {
      "database": "ok",
      "cache": "ok"
    }
  }

  503 Service Unavailable (if any check fails):
  {
    "status": "degraded",
    "version": "1.0.0",
    "timestamp": "2025-10-26T10:30:00Z",
    "checks": {
      "database": "error",
      "cache": "ok"
    },
    "errors": ["Database connection failed"]
  }
  """
  def index(conn, _params) do
    checks = perform_health_checks()
    status = determine_overall_status(checks)
    errors = extract_errors(checks)

    response = %{
      status: status,
      version: Application.spec(:thalamus, :vsn) |> to_string(),
      timestamp: DateTime.utc_now(),
      checks: format_checks(checks)
    }

    response =
      if errors != [] do
        Map.put(response, :errors, errors)
      else
        response
      end

    http_status = if status == "ok", do: :ok, else: :service_unavailable

    conn
    |> put_status(http_status)
    |> json(response)
  end

  # Private functions

  defp perform_health_checks do
    %{
      database: check_database(),
      cache: check_cache()
    }
  end

  defp check_database do
    try do
      # Simple query to check database connectivity
      case Repo.query("SELECT 1", []) do
        {:ok, _} -> {:ok, "ok"}
        {:error, reason} -> {:error, "Database error: #{inspect(reason)}"}
      end
    rescue
      error -> {:error, "Database connection failed: #{inspect(error)}"}
    end
  end

  defp check_cache do
    # Check Redis cache connectivity
    try do
      # exists? returns boolean directly
      _exists = Thalamus.Infrastructure.Adapters.RedisCacheAdapter.exists?("health_check")
      {:ok, "ok"}
    rescue
      error -> {:error, "Cache connection failed: #{inspect(error)}"}
    end
  end

  defp determine_overall_status(checks) do
    all_ok? =
      checks
      |> Map.values()
      |> Enum.all?(fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    if all_ok?, do: "ok", else: "degraded"
  end

  defp format_checks(checks) do
    checks
    |> Enum.map(fn {key, result} ->
      status =
        case result do
          {:ok, _} -> "ok"
          {:error, _} -> "error"
        end

      {key, status}
    end)
    |> Map.new()
  end

  defp extract_errors(checks) do
    checks
    |> Enum.filter(fn {_key, result} ->
      match?({:error, _}, result)
    end)
    |> Enum.map(fn {_key, {:error, message}} -> message end)
  end
end
