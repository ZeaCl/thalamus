defmodule ThalamusWeb.HealthController do
  @moduledoc """
  Minimal health check endpoint.

  Returns 200 + `{"status":"ok"}` without performing dependency checks
  (no database, no Redis) — used by load balancers and Docker healthchecks.
  Mirrors the standard used by Cranium, Cerebelum, and fm_funds.
  """

  use ThalamusWeb, :controller

  @doc """
  GET /health

  ## Response
  200 OK: `{"status":"ok"}`
  """
  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
