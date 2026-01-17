defmodule ThalamusWeb.Plugs.AgentTokenRateLimiter do
  @moduledoc """
  Rate limiter for agent token generation endpoints.

  Prevents DoS attacks by limiting requests per organization.

  ## Configuration

  Rate limits are configurable per environment:

      # config/config.exs
      config :thalamus, :rate_limits,
        agent_token_generation: [
          window_ms: 60_000,  # 1 minute window
          max_requests: 100   # 100 requests per minute
        ]

  ## Default Limits

  - **Development**: 1000 requests/minute (relaxed for testing)
  - **Production**: 100 requests/minute per organization
  - **Test**: Unlimited (disabled in test environment)

  ## Usage

      # In router.ex
      pipeline :agent_token_api do
        plug :api
        plug ThalamusWeb.Plugs.AgentTokenRateLimiter
      end

      scope "/oauth", ThalamusWeb.OAuth2 do
        pipe_through :agent_token_api

        post "/agent-token", AgentTokenController, :create
      end

  ## Response When Rate Limited

      HTTP/1.1 429 Too Many Requests
      Retry-After: 42
      Content-Type: application/json

      {
        "error": "rate_limit_exceeded",
        "message": "Maximum 100 agent tokens per minute per organization",
        "retry_after": 42
      }

  ## Implementation

  Uses Hammer (https://hex.pm/packages/hammer) for distributed rate limiting
  with ETS backend. Can be upgraded to Redis backend for multi-node deployments.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  require Logger

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    # Skip rate limiting in test environment
    if Application.get_env(:thalamus, :env) == :test do
      conn
    else
      check_rate_limit(conn)
    end
  end

  # Private Functions

  @spec check_rate_limit(Plug.Conn.t()) :: Plug.Conn.t()
  defp check_rate_limit(conn) do
    organization_id = extract_organization_id(conn)
    {window_ms, max_requests} = get_rate_limit_config()

    # Check rate limit using Hammer
    bucket = "agent_token:#{organization_id}"

    case Hammer.check_rate(bucket, window_ms, max_requests) do
      {:allow, _count} ->
        # Request allowed
        conn

      {:deny, limit} ->
        # Rate limit exceeded
        retry_after = calculate_retry_after(window_ms)

        Logger.warning(
          "Rate limit exceeded for organization: #{organization_id}. Limit: #{limit} req/#{window_ms}ms"
        )

        conn
        |> put_resp_header("retry-after", to_string(retry_after))
        |> put_status(429)
        |> json(%{
          error: "rate_limit_exceeded",
          message:
            "Maximum #{max_requests} agent tokens per #{div(window_ms, 1000)} seconds per organization",
          retry_after: retry_after
        })
        |> halt()
    end
  end

  @spec extract_organization_id(Plug.Conn.t()) :: String.t()
  defp extract_organization_id(conn) do
    # Try to extract organization_id from multiple sources:
    # 1. Request body params (for POST requests)
    # 2. Query params (for GET requests)
    # 3. Decoded JWT token (if authenticated)
    # 4. Fallback to IP address (for unauthenticated requests)

    cond do
      # From POST body
      Map.has_key?(conn.params, "organization_id") ->
        conn.params["organization_id"]

      # From decoded JWT (if authenticated)
      conn.assigns[:current_user] && conn.assigns[:current_user].organization_id ->
        conn.assigns[:current_user].organization_id

      # From IP address (fallback for unauthenticated requests)
      true ->
        get_ip_address(conn)
    end
  end

  @spec get_rate_limit_config() :: {pos_integer(), pos_integer()}
  defp get_rate_limit_config do
    env = Application.get_env(:thalamus, :env, :dev)

    case env do
      :prod ->
        # Production: strict limits
        config = Application.get_env(:thalamus, :rate_limits, [])
        agent_config = Keyword.get(config, :agent_token_generation, [])

        {
          Keyword.get(agent_config, :window_ms, 60_000),
          # 1 minute
          Keyword.get(agent_config, :max_requests, 100)
          # 100 requests/min
        }

      :dev ->
        # Development: relaxed limits for testing
        {60_000, 1000}

      :test ->
        # Test: unlimited (but this function won't be called in test env)
        {60_000, 999_999}
    end
  end

  @spec calculate_retry_after(pos_integer()) :: pos_integer()
  defp calculate_retry_after(window_ms) do
    # Calculate seconds until the rate limit window resets
    # For simplicity, return the window duration in seconds
    div(window_ms, 1000)
  end

  @spec get_ip_address(Plug.Conn.t()) :: String.t()
  defp get_ip_address(conn) do
    # Check X-Forwarded-For header first (for proxies/load balancers)
    case get_req_header(conn, "x-forwarded-for") do
      [ip_list | _] ->
        # X-Forwarded-For can have multiple IPs, take the first
        ip_list
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        # Fallback to remote_ip
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end
