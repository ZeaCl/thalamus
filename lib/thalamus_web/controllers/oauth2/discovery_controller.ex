defmodule ThalamusWeb.OAuth2.DiscoveryController do
  @moduledoc """
  OpenID Connect Discovery Controller.

  Implements OpenID Connect Discovery 1.0 specification.
  Provides server metadata at /.well-known/openid-configuration

  Reference: https://openid.net/specs/openid-connect-discovery-1_0.html
  """

  use ThalamusWeb, :controller

  @doc """
  GET /.well-known/openid-configuration

  Returns OpenID Connect Discovery metadata.

  ## Response

  Returns a JSON document containing OAuth2/OIDC server metadata:
  - issuer: The authorization server's issuer identifier
  - authorization_endpoint: OAuth2 authorization endpoint
  - token_endpoint: OAuth2 token endpoint
  - userinfo_endpoint: OpenID Connect UserInfo endpoint
  - response_types_supported: OAuth2 response types supported
  - grant_types_supported: OAuth2 grant types supported
  - scopes_supported: OAuth2 scopes supported
  - And more...

  ## Examples

      # Request
      GET /.well-known/openid-configuration

      # Response
      {
        "issuer": "http://localhost:4000",
        "authorization_endpoint": "http://localhost:4000/oauth/authorize",
        "token_endpoint": "http://localhost:4000/oauth/token",
        ...
      }
  """
  def show(conn, _params) do
    # Build base URL from connection
    base_url = get_base_url(conn)

    # Build discovery document
    discovery = %{
      # REQUIRED: Issuer identifier
      issuer: base_url,

      # REQUIRED: OAuth2 authorization endpoint
      authorization_endpoint: "#{base_url}/oauth/authorize",

      # REQUIRED: OAuth2 token endpoint
      token_endpoint: "#{base_url}/oauth/token",

      # RECOMMENDED: OpenID Connect UserInfo endpoint
      userinfo_endpoint: "#{base_url}/oauth/userinfo",

      # OPTIONAL: RFC 7662 Token Introspection endpoint
      introspection_endpoint: "#{base_url}/oauth/introspect",

      # OPTIONAL: RFC 7009 Token Revocation endpoint
      revocation_endpoint: "#{base_url}/oauth/revoke",

      # REQUIRED: OAuth2 response types supported
      response_types_supported: [
        "code"
        # "token" and "id_token" not supported (implicit flow disabled for security)
      ],

      # OPTIONAL: OAuth2 grant types supported
      grant_types_supported: [
        "authorization_code",
        "client_credentials",
        "refresh_token"
        # "password" and "implicit" not supported for security
      ],

      # REQUIRED: Subject types supported
      subject_types_supported: [
        "public"
        # "pairwise" not supported yet
      ],

      # REQUIRED: ID Token signing algorithms supported
      id_token_signing_alg_values_supported: [
        "RS256"
        # Could add HS256, ES256 in future
      ],

      # RECOMMENDED: OAuth2 scopes supported
      scopes_supported: [
        # Standard OpenID Connect scopes
        "openid",
        "profile",
        "email",
        "address",
        "phone",
        "offline_access"
      ],

      # RECOMMENDED: Token endpoint authentication methods
      token_endpoint_auth_methods_supported: [
        "client_secret_basic",
        "client_secret_post"
        # Could add "private_key_jwt" in future
      ],

      # OPTIONAL: Claims supported
      claims_supported: [
        "sub",
        "name",
        "email",
        "email_verified",
        "phone_number",
        "phone_number_verified",
        "updated_at"
      ],

      # OPTIONAL: Code challenge methods supported (PKCE)
      code_challenge_methods_supported: [
        "S256",
        "plain"
      ],

      # OPTIONAL: Response modes supported
      response_modes_supported: [
        "query",
        "fragment"
      ],

      # OPTIONAL: Service documentation URL
      service_documentation: "#{base_url}/docs",

      # OPTIONAL: UI locales supported
      ui_locales_supported: [
        "en"
      ]
    }

    json(conn, discovery)
  end

  # Private helper functions

  defp get_base_url(conn) do
    # Get scheme (http or https)
    scheme = if conn.scheme == :https, do: "https", else: "http"

    # Get host from configuration or request
    host = get_host(conn)

    # Get port (omit default ports)
    port = get_port_string(conn)

    # Build base URL
    "#{scheme}://#{host}#{port}"
  end

  defp get_host(conn) do
    # Try to get from configuration first
    configured_host = Application.get_env(:thalamus, :host)

    if configured_host do
      configured_host
    else
      # Fallback to request host
      conn.host
    end
  end

  defp get_port_string(conn) do
    port = conn.port

    # Omit default ports (80 for HTTP, 443 for HTTPS)
    cond do
      conn.scheme == :http and port == 80 -> ""
      conn.scheme == :https and port == 443 -> ""
      true -> ":#{port}"
    end
  end
end
