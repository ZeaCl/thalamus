defmodule ThalamusWeb.URLHelpers do
  @moduledoc """
  Helpers for dynamically resolving base URLs, redirect URIs, and return URLs.

  Ensures Thalamus is completely decoupled from any specific domain or environment,
  enabling it to run as a multi-tenant cloud service (auth.zea.cl), local development (localhost),
  or on-premise / self-hosted open-source installations without hardcoded URLs.
  """

  @doc """
  Builds the base URL (scheme://host[:port]) from the connection,
  respecting reverse proxy headers (X-Forwarded-Proto, X-Forwarded-Host, X-Forwarded-Port)
  and falling back to application configuration / Endpoint.url().
  """
  def base_url(conn \\ nil)

  def base_url(%Plug.Conn{} = conn) do
    scheme =
      case Plug.Conn.get_req_header(conn, "x-forwarded-proto") do
        ["https" | _] -> "https"
        ["http" | _] -> "http"
        _ -> if conn.scheme == :https, do: "https", else: "http"
      end

    host =
      case Plug.Conn.get_req_header(conn, "x-forwarded-host") do
        [forwarded_host | _] -> forwarded_host
        _ -> Application.get_env(:thalamus, :host) || conn.host
      end

    if String.contains?(host, ":") do
      "#{scheme}://#{host}"
    else
      public_port = Application.get_env(:thalamus, :public_port)

      port =
        case Plug.Conn.get_req_header(conn, "x-forwarded-port") do
          [forwarded_port | _] ->
            case Integer.parse(forwarded_port) do
              {p, _} -> p
              :error -> conn.port
            end

          _ ->
            public_port || conn.port
        end

      port_str =
        cond do
          scheme == "http" and port == 80 -> ""
          scheme == "https" and port == 443 -> ""
          is_integer(port) and port > 0 -> ":#{port}"
          true -> ""
        end

      "#{scheme}://#{host}#{port_str}"
    end
  end

  def base_url(nil) do
    System.get_env("BASE_URL") ||
      System.get_env("PUBLIC_URL") ||
      ThalamusWeb.Endpoint.url()
  end

  @doc """
  Resolves the callback redirect URI for a social provider.
  Uses the provider-specific environment variable if set, otherwise computes it dynamically from base_url.
  """
  def resolve_social_redirect_uri(conn, provider) do
    provider_str = to_string(provider) |> String.downcase()

    configured =
      case provider_str do
        "google" ->
          Application.get_env(:thalamus, :google_auth, [])[:redirect_uri] ||
            System.get_env("GOOGLE_REDIRECT_URI")

        "github" ->
          Application.get_env(:thalamus, :github_auth, [])[:redirect_uri] ||
            System.get_env("GITHUB_REDIRECT_URI")

        "apple" ->
          Application.get_env(:thalamus, :apple_auth, [])[:redirect_uri] ||
            System.get_env("APPLE_REDIRECT_URI")

        _ ->
          nil
      end

    if is_binary(configured) and configured != "" do
      configured
    else
      "#{base_url(conn)}/auth/social/#{provider_str}/callback"
    end
  end

  @doc """
  Resolves the default redirect/dashboard URL after login.
  """
  def default_return_to(_conn \\ nil) do
    System.get_env("DEFAULT_REDIRECT_URL") || "/"
  end

  @doc """
  Resolves the default logout URL.
  """
  def default_logout_url(_conn \\ nil) do
    System.get_env("DEFAULT_LOGOUT_URL") || "/login"
  end

  @doc """
  Resolves the home / landing page URL.
  """
  def home_url(_conn \\ nil) do
    System.get_env("HOME_URL") || "/"
  end
end
