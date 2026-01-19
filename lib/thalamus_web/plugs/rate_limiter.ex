defmodule ThalamusWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate Limiting Plug for API protection.

  Implements token bucket rate limiting to protect against abuse.
  Uses Redis for distributed rate limiting across multiple nodes.

  SOLID Principles Applied:
  - Single Responsibility: Only handles rate limiting
  - Open/Closed: Configurable limits without code changes
  - Dependency Inversion: Uses CacheService port

  ## Configuration

  In your pipeline or controller:

      plug ThalamusWeb.Plugs.RateLimiter,
        limit: 100,
        window: 60_000,  # 1 minute in milliseconds
        key: :ip_address

  ## Rate Limit Strategies

  - `:ip_address` - Limit by client IP address
  - `:user_id` - Limit by authenticated user
  - `:client_id` - Limit by OAuth2 client
  - Custom function: `fn conn -> "custom:key" end`

  ## Response Headers

  When rate limited, the following headers are included:
  - X-RateLimit-Limit: Maximum requests allowed
  - X-RateLimit-Remaining: Requests remaining in window
  - X-RateLimit-Reset: Unix timestamp when limit resets
  - Retry-After: Seconds until limit resets

  ## Examples

      # Global API rate limit (per IP)
      pipeline :api do
        plug :accepts, ["json"]
        plug ThalamusWeb.Plugs.RateLimiter,
          limit: 1000,
          window: 60_000,
          key: :ip_address
      end

      # Strict limit for authentication endpoints
      scope "/oauth", ThalamusWeb.OAuth2 do
        plug ThalamusWeb.Plugs.RateLimiter,
          limit: 10,
          window: 60_000,
          key: :ip_address

        post "/token", TokenController, :create
      end

      # Per-user limits for authenticated endpoints
      pipeline :authenticated_api do
        plug ThalamusWeb.Plugs.AuthenticateToken
        plug ThalamusWeb.Plugs.RateLimiter,
          limit: 5000,
          window: 60_000,
          key: :user_id
      end
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Thalamus.Infrastructure.Adapters.RedisCacheAdapter

  @default_limit 100
  # 1 minute
  @default_window 60_000

  def init(opts) do
    %{
      limit: Keyword.get(opts, :limit, @default_limit),
      window: Keyword.get(opts, :window, @default_window),
      key_strategy: Keyword.get(opts, :key, :ip_address)
    }
  end

  def call(conn, opts) do
    # Check if rate limiting is enabled (can be disabled in test environment)
    rate_limiting_enabled = Application.get_env(:thalamus, :rate_limiting_enabled, true)

    if rate_limiting_enabled do
      # Generate rate limit key
      rate_limit_key = generate_key(conn, opts.key_strategy)

      # Check rate limit
      case check_rate_limit(rate_limit_key, opts.limit, opts.window) do
        {:ok, remaining, reset_at} ->
          # Within limit - add headers and continue
          conn
          |> put_rate_limit_headers(opts.limit, remaining, reset_at)

        {:error, :rate_limited, retry_after} ->
          # Rate limit exceeded
          rate_limit_exceeded(conn, opts.limit, retry_after)
      end
    else
      # Rate limiting disabled - pass through without checks
      conn
    end
  end

  # Private functions

  defp generate_key(conn, :ip_address) do
    ip = get_client_ip(conn)
    "rate_limit:ip:#{ip}"
  end

  defp generate_key(conn, :user_id) do
    case conn.assigns[:current_user_id] do
      nil ->
        # Fall back to IP if no user
        generate_key(conn, :ip_address)

      user_id ->
        "rate_limit:user:#{user_id}"
    end
  end

  defp generate_key(conn, :client_id) do
    case conn.assigns[:current_client_id] do
      nil ->
        # Fall back to IP if no client
        generate_key(conn, :ip_address)

      client_id ->
        "rate_limit:client:#{client_id}"
    end
  end

  defp generate_key(conn, key_fn) when is_function(key_fn, 1) do
    key_fn.(conn)
  end

  defp generate_key(_conn, key) when is_binary(key) do
    "rate_limit:custom:#{key}"
  end

  defp check_rate_limit(key, limit, window_ms) do
    # Current timestamp in seconds
    now = System.system_time(:second)

    # Try to increment counter
    case RedisCacheAdapter.increment(key, 1) do
      {:ok, count} ->
        if count == 1 do
          # First request in window - set expiration
          ttl_seconds = div(window_ms, 1000)
          RedisCacheAdapter.expire(key, ttl_seconds)
        end

        if count <= limit do
          # Within limit
          remaining = limit - count
          reset_at = now + div(window_ms, 1000)
          {:ok, remaining, reset_at}
        else
          # Exceeded limit
          case RedisCacheAdapter.ttl(key) do
            {:ok, ttl} when ttl > 0 ->
              {:error, :rate_limited, ttl}

            _ ->
              # Key expired or error - reset and allow
              RedisCacheAdapter.delete(key)
              check_rate_limit(key, limit, window_ms)
          end
        end

      {:error, _reason} ->
        # Cache error - fail open (allow request)
        # In production, you might want to fail closed instead
        {:ok, limit - 1, now + div(window_ms, 1000)}
    end
  end

  defp put_rate_limit_headers(conn, limit, remaining, reset_at) do
    conn
    |> put_resp_header("x-ratelimit-limit", to_string(limit))
    |> put_resp_header("x-ratelimit-remaining", to_string(max(remaining, 0)))
    |> put_resp_header("x-ratelimit-reset", to_string(reset_at))
  end

  defp rate_limit_exceeded(conn, limit, retry_after) do
    conn
    |> put_status(:too_many_requests)
    |> put_resp_header("x-ratelimit-limit", to_string(limit))
    |> put_resp_header("x-ratelimit-remaining", "0")
    |> put_resp_header("retry-after", to_string(retry_after))
    |> json(%{
      error: "rate_limit_exceeded",
      error_description: "Too many requests. Please try again later.",
      retry_after: retry_after
    })
    |> halt()
  end

  defp get_client_ip(conn) do
    # Try to get real IP from X-Forwarded-For header (if behind proxy)
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        # Take first IP in the chain
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        # Fall back to remote_ip
        case conn.remote_ip do
          {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
          {a, b, c, d, e, f, g, h} -> "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
          _ -> "unknown"
        end
    end
  end
end
