defmodule ThalamusWeb.OAuth2.DeviceController do
  @moduledoc """
  OAuth2 Device Flow Controller (RFC 8628).

  Handles:
  - POST /oauth/device — initiates device authorization
  - GET  /oauth/activate — shows the user_code entry form
  - POST /oauth/activate — processes user_code submission and authorizes

  SOLID Principles Applied:
  - Single Responsibility: Only handles device flow HTTP requests
  - Dependency Inversion: Depends on ports, not implementations
  """

  use ThalamusWeb, :controller

  alias Thalamus.Domain.Entities.DeviceAuthorization
  alias Thalamus.Infrastructure.Repositories.PostgreSQLOAuth2ClientRepository
  alias Thalamus.Infrastructure.Repositories.PostgreSQLDeviceAuthorizationRepository

  @repo PostgreSQLDeviceAuthorizationRepository

  @doc """
  POST /oauth/device

  Initiates the OAuth2 Device Authorization flow.
  Generates a device_code and user_code for the client.

  ## Request (form-urlencoded or JSON)
  - client_id (required): OAuth2 client identifier
  - scope (optional): requested scopes, space-separated

  ## Response (200 OK)
  {
    "device_code": "XK7...",
    "user_code": "ABCD-EFGH",
    "verification_uri": "https://auth.zea.cl/oauth/activate",
    "verification_uri_complete": "https://auth.zea.cl/oauth/activate?code=ABCD-EFGH",
    "expires_in": 600,
    "interval": 5
  }
  """
  def create(conn, params) do
    client_id_string = params["client_id"] || params[:client_id] || ""
    scope = params["scope"] || params[:scope] || "openid profile email"
    scopes = String.split(scope, " ", trim: true)

    with {:ok, client} <- validate_client(client_id_string),
         client_uuid = extract_client_uuid(client),
         {:ok, device_auth} <- DeviceAuthorization.new(client_id: client_uuid, scopes: scopes),
         {:ok, stored} <- @repo.store(device_auth) do
      verification_uri = build_verification_uri(conn)

      conn
      |> put_status(:ok)
      |> put_resp_header("cache-control", "no-store")
      |> json(%{
        device_code: stored.device_code,
        user_code: stored.user_code,
        verification_uri: verification_uri,
        verification_uri_complete: "#{verification_uri}?code=#{stored.user_code}",
        expires_in: 600,
        interval: stored.interval
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_client", error_description: "Client not found"})

      {:error, :client_inactive} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_client", error_description: "Client is not active"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "invalid_request",
          error_description: "Device authorization failed: #{inspect(reason)}"
        })
    end
  end

  @doc """
  GET /oauth/activate

  Shows the device activation page where the user enters their user_code.
  """
  def new(conn, %{"code" => code}) do
    render(conn, :activate, user_code: code, error: nil)
  end

  def new(conn, _params) do
    render(conn, :activate, user_code: nil, error: nil)
  end

  @doc """
  POST /oauth/activate

  Processes the device activation form submission.
  Verifies the user_code and authorizes the device if valid.
  """
  def activate(conn, params) do
    user_code = params["user_code"] || ""

    # Format the entered code (allow both "ABCD-EFGH" and "ABCDEFGH")
    formatted_code = normalize_user_code(user_code)

    case @repo.find_by_user_code(formatted_code) do
      {:ok, device_auth} ->
        if DeviceAuthorization.pending?(device_auth) do
          user_id = get_session(conn, :user_id)

          if is_nil(user_id) do
            # User not logged in — redirect to login with return path
            return_to = ~p"/oauth/activate?code=#{formatted_code}"

            conn
            |> put_flash(:info, "Please log in to authorize the device.")
            |> redirect(to: ~p"/login?return_to=#{URI.encode_www_form(return_to)}")
          else
            case @repo.authorize(device_auth, user_id) do
              {:ok, _authorized} ->
                render(conn, :success,
                  user_code: formatted_code,
                  client_name: "the application"
                )

              {:error, _} ->
                render(conn, :activate,
                  user_code: formatted_code,
                  error: "Failed to authorize. Please try again."
                )
            end
          end
        else
          render(conn, :activate,
            user_code: formatted_code,
            error: "This code has expired. Please start a new device login."
          )
        end

      {:error, :not_found} ->
        render(conn, :activate,
          user_code: formatted_code,
          error: "Invalid code. Please check and try again."
        )
    end
  end

  # ── Private helpers ──────────────────────────────────────────

  defp validate_client(client_id) when is_binary(client_id) and client_id != "" do
    case PostgreSQLOAuth2ClientRepository.find_by_client_id(client_id) do
      {:ok, client} ->
        if client.is_active do
          {:ok, client}
        else
          {:error, :client_inactive}
        end

      {:error, _} ->
        {:error, :not_found}
    end
  end

  defp validate_client(_), do: {:error, :not_found}

  defp extract_client_uuid(client) do
    if is_struct(client.id) do
      client.id.value |> String.replace_prefix("client_", "")
    else
      client.id
    end
  end

  defp build_verification_uri(conn) do
    # Check X-Forwarded-Proto for reverse proxy (Caddy, nginx)
    scheme =
      case Plug.Conn.get_req_header(conn, "x-forwarded-proto") do
        ["https" | _] -> "https"
        _ -> if conn.scheme == :http, do: "http", else: "https"
      end

    host = conn.host
    port = if conn.port in [80, 443], do: "", else: ":#{conn.port}"
    "#{scheme}://#{host}#{port}/oauth/activate"
  end

  defp normalize_user_code(code) when is_binary(code) do
    cleaned = String.upcase(String.replace(code, ~r/[^A-Z0-9]/, ""))

    if String.length(cleaned) == 8 do
      # Format as XXXX-XXXX
      <<a::binary-size(4), b::binary-size(4)>> = cleaned
      "#{a}-#{b}"
    else
      # Return cleaned version — find_by_user_code will return :not_found
      # and the controller will show "Invalid code" to the user
      cleaned
    end
  end
end
