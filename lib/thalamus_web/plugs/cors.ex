defmodule ThalamusWeb.Plugs.CORS do
  @moduledoc """
  CORS (Cross-Origin Resource Sharing) Plug.

  Handles CORS preflight requests and adds appropriate headers
  to allow cross-origin requests from allowed origins.

  SOLID Principles Applied:
  - Single Responsibility: Only handles CORS headers
  - Open/Closed: Configurable without code changes

  ## Configuration

  In config/config.exs:

      config :thalamus, ThalamusWeb.Plugs.CORS,
        origins: ["https://app.example.com", "https://admin.example.com"],
        allow_credentials: true,
        max_age: 86400,
        expose_headers: ["x-ratelimit-limit", "x-ratelimit-remaining"]

  Or in development (allow all):

      config :thalamus, ThalamusWeb.Plugs.CORS,
        origins: "*",
        allow_credentials: false

  ## Usage

  Add to your endpoint.ex:

      plug ThalamusWeb.Plugs.CORS

  ## Security Notes

  - In production, always specify exact origins (never use "*" with credentials)
  - Only expose headers that are safe to share
  - Use appropriate max_age to reduce preflight requests
  - Consider the security implications of allow_credentials
  """

  import Plug.Conn

  @default_origins ["http://localhost:3000", "http://localhost:4000"]
  @default_methods ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
  @default_headers ["Accept", "Authorization", "Content-Type", "Origin"]
  @default_expose_headers []
  # 24 hours
  @default_max_age 86400
  @default_allow_credentials false

  def init(opts), do: opts

  def call(conn, _opts) do
    config = get_config()
    origin = get_req_header(conn, "origin") |> List.first()

    cond do
      # OPTIONS request (preflight)
      conn.method == "OPTIONS" ->
        handle_preflight(conn, origin, config)

      # Regular request with Origin header
      origin != nil ->
        handle_cors(conn, origin, config)

      # No Origin header (same-origin request)
      true ->
        conn
    end
  end

  # Private functions

  defp handle_preflight(conn, origin, config) do
    if origin_allowed?(origin, config.origins) do
      conn
      |> put_cors_headers(origin, config)
      |> put_resp_header("access-control-allow-methods", Enum.join(config.methods, ", "))
      |> put_resp_header("access-control-allow-headers", Enum.join(config.headers, ", "))
      |> put_resp_header("access-control-max-age", to_string(config.max_age))
      |> send_resp(204, "")
      |> halt()
    else
      # Origin not allowed - return 403
      conn
      |> send_resp(403, "")
      |> halt()
    end
  end

  defp handle_cors(conn, origin, config) do
    if origin_allowed?(origin, config.origins) do
      put_cors_headers(conn, origin, config)
    else
      # Origin not allowed - don't add CORS headers
      conn
    end
  end

  defp put_cors_headers(conn, origin, config) do
    conn
    |> put_resp_header("access-control-allow-origin", origin)
    |> maybe_put_credentials(config.allow_credentials)
    |> maybe_put_expose_headers(config.expose_headers)
    |> put_resp_header("vary", "Origin")
  end

  defp origin_allowed?(_origin, "*"), do: true
  defp origin_allowed?(nil, _origins), do: false

  defp origin_allowed?(origin, origins) when is_list(origins) do
    Enum.any?(origins, fn allowed_origin ->
      cond do
        # Allow all
        allowed_origin == "*" ->
          true

        # Exact match
        allowed_origin == origin ->
          true

        # Wildcard port: http://localhost:* matches http://localhost:5299 etc
        String.ends_with?(allowed_origin, ":*") ->
          base = String.replace_suffix(allowed_origin, ":*", "")
          String.starts_with?(origin, base <> ":")

        # Wildcard subdomain (e.g., "*.example.com")
        String.starts_with?(allowed_origin, "*.") ->
          domain = String.replace_prefix(allowed_origin, "*", "")
          String.ends_with?(origin, domain)

        # No match
        true ->
          false
      end
    end)
  end

  defp maybe_put_credentials(conn, true) do
    put_resp_header(conn, "access-control-allow-credentials", "true")
  end

  defp maybe_put_credentials(conn, false), do: conn

  defp maybe_put_expose_headers(conn, []), do: conn

  defp maybe_put_expose_headers(conn, headers) when is_list(headers) do
    put_resp_header(conn, "access-control-expose-headers", Enum.join(headers, ", "))
  end

  defp get_config do
    config = Application.get_env(:thalamus, __MODULE__, [])

    %{
      origins: Keyword.get(config, :origins, @default_origins),
      methods: Keyword.get(config, :methods, @default_methods),
      headers: Keyword.get(config, :headers, @default_headers),
      expose_headers: Keyword.get(config, :expose_headers, @default_expose_headers),
      max_age: Keyword.get(config, :max_age, @default_max_age),
      allow_credentials: Keyword.get(config, :allow_credentials, @default_allow_credentials)
    }
  end
end
