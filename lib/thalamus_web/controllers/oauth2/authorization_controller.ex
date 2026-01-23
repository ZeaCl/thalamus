defmodule ThalamusWeb.OAuth2.AuthorizationController do
  @moduledoc """
  OAuth2 Authorization Endpoint Controller.

  Implements RFC 6749 - OAuth 2.0 Authorization Endpoint
  Implements RFC 7636 - PKCE (Proof Key for Code Exchange)

  This endpoint handles the authorization code flow:
  1. User is redirected here by the client application
  2. User authenticates (if not already)
  3. User grants/denies permission
  4. Authorization code is generated and returned to client

  SOLID Principles Applied:
  - Single Responsibility: Only handles authorization HTTP requests
  - Dependency Inversion: Depends on Use Cases, not implementations
  """

  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLOAuth2ClientRepository,
    PostgreSQLTokenRepository
  }

  alias Thalamus.Domain.ValueObjects.{
    UserId,
    Scope,
    AuthorizationCode,
    PKCEChallenge,
    RedirectUri
  }

  @doc """
  GET /oauth/authorize

  Authorization endpoint for OAuth2 authorization code flow.

  ## Query Parameters (as per RFC 6749)
  - response_type (required): Must be "code"
  - client_id (required): The client identifier
  - redirect_uri (optional): Where to redirect after authorization
  - scope (optional): Space-delimited list of scopes
  - state (recommended): Opaque value for CSRF protection
  - code_challenge (optional, PKCE): SHA256 hash of code_verifier
  - code_challenge_method (optional, PKCE): "S256" or "plain"

  ## Response
  - 302 Redirect to login if user not authenticated
  - 200 OK with consent screen if user authenticated
  - 302 Redirect to redirect_uri with authorization code on approval
  - 302 Redirect to redirect_uri with error on denial

  ## Examples

      # Request
      GET /oauth/authorize?response_type=code&client_id=abc123&redirect_uri=https://app.com/callback&scope=openid%20profile&state=xyz

      # Success Response (redirect)
      Location: https://app.com/callback?code=ac_xxxx&state=xyz

      # Error Response (redirect)
      Location: https://app.com/callback?error=access_denied&state=xyz
  """
  def new(conn, params) do
    # Validate required OAuth2 parameters
    # NOTE: Per RFC 6749, response_type and client_id MUST be validated BEFORE
    # considering redirect_uri for error responses (security requirement)
    with {:ok, response_type} <- validate_response_type(params["response_type"]),
         {:ok, client_id_string} <- validate_client_id_param(params["client_id"]),
         {:ok, client} <- PostgreSQLOAuth2ClientRepository.find_by_client_id(client_id_string),
         {:ok, redirect_uri} <- validate_redirect_uri(params["redirect_uri"], client),
         {:ok, scopes} <- parse_scopes(params["scope"]),
         {:ok, final_scopes} <- validate_and_finalize_scopes(scopes, client),
         {:ok, pkce_params} <- extract_and_validate_pkce_params(params) do
      # Check if user is authenticated
      case get_authenticated_user(conn) do
        {:ok, _user_id} ->
          # User is authenticated - show consent screen
          render_consent_screen(conn, %{
            client: client,
            client_id_string: client_id_string,
            scopes: final_scopes,
            redirect_uri: redirect_uri,
            state: params["state"],
            response_type: response_type,
            pkce_params: pkce_params
          })

        {:error, :not_authenticated} ->
          # User not authenticated - redirect to login
          # Store authorization request in session for after login
          conn
          |> put_session(:authorization_request, params)
          |> redirect(to: "/login?return_to=" <> URI.encode_www_form("/oauth/authorize"))
      end
    else
      {:error, error_code, description} ->
        # Return 400 error for validation failures
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: error_code,
          error_description: description
        })

      {:error, :not_found} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "invalid_client",
          error_description: "Client not found"
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "invalid_request",
          error_description: "Invalid authorization request: #{inspect(reason)}"
        })
    end
  end

  @doc """
  POST /oauth/authorize

  Processes the user's consent decision.

  ## Request Body
  - decision: "approve" or "deny"
  - client_id: The client identifier
  - redirect_uri: Where to redirect
  - scope: Requested scopes
  - state: CSRF protection token
  - code_challenge: PKCE challenge (if applicable)
  - code_challenge_method: PKCE method

  ## Response
  - 302 Redirect to redirect_uri with authorization code (if approved)
  - 302 Redirect to redirect_uri with error (if denied)
  """
  def create(conn, params) do
    decision = params["decision"]

    with {:ok, user_id} <- get_authenticated_user(conn),
         {:ok, client_id_string} <- validate_client_id_param(params["client_id"]),
         {:ok, client} <- PostgreSQLOAuth2ClientRepository.find_by_client_id(client_id_string),
         {:ok, redirect_uri} <- validate_redirect_uri(params["redirect_uri"], client),
         {:ok, scopes} <- parse_scopes(params["scope"]),
         {:ok, final_scopes} <- validate_and_finalize_scopes(scopes, client) do
      case decision do
        "approve" ->
          # User approved - generate authorization code
          generate_authorization_code(conn, %{
            client_id: client.id,
            user_id: user_id,
            redirect_uri: redirect_uri,
            scopes: final_scopes,
            state: params["state"],
            code_challenge: params["code_challenge"],
            code_challenge_method: params["code_challenge_method"]
          })

        "deny" ->
          # User denied - redirect with access_denied error
          redirect_with_error(
            conn,
            redirect_uri,
            "access_denied",
            "The user denied the authorization request",
            params["state"]
          )

        _ ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "invalid_request", error_description: "Invalid decision parameter"})
      end
    else
      {:error, :not_authenticated} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized", error_description: "User not authenticated"})

      {:error, error_code, description} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: error_code, error_description: description})

      {:error, :not_found} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_client", error_description: "Client not found"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_request", error_description: inspect(reason)})
    end
  end

  # Private helper functions

  defp validate_response_type("code"), do: {:ok, "code"}

  defp validate_response_type(_),
    do: {:error, "unsupported_response_type", "Only 'code' response type is supported"}

  defp validate_client_id_param(nil),
    do: {:error, "invalid_request", "Missing client_id parameter"}

  defp validate_client_id_param(""),
    do: {:error, "invalid_request", "Missing client_id parameter"}

  defp validate_client_id_param(client_id), do: {:ok, client_id}

  defp validate_redirect_uri(nil, client) do
    # If no redirect_uri provided, use the first registered one
    case client.redirect_uris do
      [first_uri | _] -> {:ok, RedirectUri.to_string(first_uri)}
      [] -> {:error, "invalid_request", "No redirect_uri available"}
    end
  end

  defp validate_redirect_uri(redirect_uri, client) do
    # Convert client redirect_uris (Value Objects) to strings for comparison
    allowed_uris = Enum.map(client.redirect_uris, &redirect_uri_to_string/1)

    # Check if redirect_uri is in the client's registered URIs
    if redirect_uri in allowed_uris do
      {:ok, redirect_uri}
    else
      {:error, "invalid_request", "Invalid redirect_uri"}
    end
  end

  defp redirect_uri_to_string(%RedirectUri{value: value}), do: value
  defp redirect_uri_to_string(str) when is_binary(str), do: str

  defp parse_scopes(nil), do: {:ok, []}
  defp parse_scopes(""), do: {:ok, []}

  defp parse_scopes(scope_string) when is_binary(scope_string) do
    scopes =
      scope_string
      |> String.split(" ", trim: true)
      |> Enum.map(fn scope_str ->
        case Scope.new(scope_str) do
          {:ok, scope} -> scope
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, scopes}
  end

  defp extract_and_validate_pkce_params(params) do
    code_challenge = params["code_challenge"]
    code_challenge_method = params["code_challenge_method"] || "S256"

    # If PKCE is provided, validate the method
    if code_challenge do
      case code_challenge_method do
        method when method in ["S256", "plain"] ->
          {:ok, %{code_challenge: code_challenge, code_challenge_method: method}}

        _ ->
          {:error, "invalid_request", "Invalid code_challenge_method. Only S256 and plain are supported"}
      end
    else
      # No PKCE provided - that's OK (though not recommended)
      {:ok, %{code_challenge: nil, code_challenge_method: nil}}
    end
  end

  defp validate_and_finalize_scopes(requested_scopes, client) do
    # Use client's allowed scopes if no scopes were requested
    final_scopes = if Enum.empty?(requested_scopes), do: client.allowed_scopes, else: requested_scopes

    # Validate that all requested scopes are in client's allowed list
    if Enum.empty?(final_scopes) do
      {:error, "invalid_scope", "No scopes available for this client"}
    else
      # Convert scopes to comparable format (all to strings)
      requested_scope_strings = Enum.map(final_scopes, &scope_to_string/1)
      allowed_scope_strings = Enum.map(client.allowed_scopes, &scope_to_string/1)

      unauthorized_scopes =
        Enum.reject(requested_scope_strings, fn scope ->
          scope in allowed_scope_strings
        end)

      if Enum.empty?(unauthorized_scopes) do
        {:ok, final_scopes}
      else
        {:error, "invalid_scope", "Requested scopes not allowed for this client: #{Enum.join(unauthorized_scopes, ", ")}"}
      end
    end
  end

  defp scope_to_string(%Scope{value: value}), do: value
  defp scope_to_string(str) when is_binary(str), do: str

  defp get_authenticated_user(conn) do
    # Check if user is authenticated via session or token
    # For now, we'll check conn.assigns (set by authentication middleware)
    case conn.assigns[:current_user_id] do
      nil ->
        # Try to get from session
        case get_session(conn, :user_id) do
          nil ->
            {:error, :not_authenticated}

          user_id_string ->
            case UserId.from_string(user_id_string) do
              {:ok, user_id} -> {:ok, user_id}
              {:error, _} -> {:error, :not_authenticated}
            end
        end

      user_id when is_binary(user_id) ->
        case UserId.from_string(user_id) do
          {:ok, user_id_vo} -> {:ok, user_id_vo}
          {:error, _} -> {:error, :not_authenticated}
        end

      user_id ->
        {:ok, user_id}
    end
  end

  defp render_consent_screen(conn, data) do
    # Convert scopes to strings for rendering (handle both Scope structs and strings)
    scope_strings = Enum.map(data.scopes, &scope_to_string/1)

    # Render HTML consent screen
    render(conn, :consent,
      client_name: data.client.name,
      scopes: scope_strings,
      redirect_uri: data.redirect_uri,
      state: data.state,
      form_data: %{
        client_id: data.client_id_string,
        redirect_uri: data.redirect_uri,
        scope: Enum.join(scope_strings, " "),
        state: data.state,
        code_challenge: data.pkce_params.code_challenge,
        code_challenge_method: data.pkce_params.code_challenge_method
      }
    )
  end

  defp generate_authorization_code(conn, data) do
    # Create PKCE challenge if provided
    pkce_challenge =
      if data.code_challenge do
        # Convert string to atom with validation
        method =
          case data.code_challenge_method do
            "S256" -> :S256
            "plain" -> :plain
            # Default to S256 for security
            _ -> :S256
          end

        case PKCEChallenge.new(data.code_challenge, method) do
          {:ok, challenge} ->
            challenge

          {:error, reason} ->
            # Log the error and return error to client
            require Logger

            Logger.error(
              "Invalid PKCE challenge: #{inspect(reason)}, challenge: #{data.code_challenge}"
            )

            # Return nil - this will cause the authorization code generation to fail gracefully
            nil
        end
      else
        nil
      end

    # Generate authorization code
    case AuthorizationCode.generate(
           data.client_id,
           data.user_id,
           build_redirect_uri_vo(data.redirect_uri),
           data.scopes,
           pkce_challenge,
           # 10 minutes expiry
           600
         ) do
      {:ok, auth_code} ->
        # Store authorization code in database
        # Extract UUID from client_id value object (removes "client_" prefix)
        client_uuid =
          auth_code.client_id.value
          |> String.replace_prefix("client_", "")

        token_data = %{
          token: AuthorizationCode.to_string(auth_code),
          type: :authorization_code,
          client_id: client_uuid,
          user_id: UserId.to_string(data.user_id),
          scopes: Enum.map(data.scopes, &Scope.to_string/1),
          expires_at: auth_code.expires_at,
          code_challenge: data.code_challenge,
          code_challenge_method: data.code_challenge_method
        }

        case PostgreSQLTokenRepository.store(token_data) do
          :ok ->
            # Redirect back to client with authorization code
            redirect_with_code(conn, data.redirect_uri, auth_code.code, data.state)

          {:error, reason} ->
            require Logger
            Logger.error("Failed to store authorization code: #{inspect(reason)}")

            redirect_with_error(
              conn,
              data.redirect_uri,
              "server_error",
              "Failed to generate authorization code",
              data.state
            )
        end

      {:error, reason} ->
        require Logger
        Logger.error("Failed to generate authorization code entity: #{inspect(reason)}")

        redirect_with_error(
          conn,
          data.redirect_uri,
          "server_error",
          "Failed to generate authorization code",
          data.state
        )
    end
  end

  defp redirect_with_code(conn, redirect_uri, code, state) do
    # Build redirect URI with authorization code
    uri = URI.parse(redirect_uri)

    query_params = URI.decode_query(uri.query || "")
    query_params = Map.put(query_params, "code", code)

    query_params =
      if state do
        Map.put(query_params, "state", state)
      else
        query_params
      end

    new_query = URI.encode_query(query_params)
    final_uri = %{uri | query: new_query} |> URI.to_string()

    conn
    |> put_resp_header("location", final_uri)
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("pragma", "no-cache")
    |> send_resp(302, "")
  end

  defp redirect_with_error(conn, redirect_uri, error, description, state) do
    uri = URI.parse(redirect_uri)

    query_params = URI.decode_query(uri.query || "")
    query_params = Map.put(query_params, "error", error)
    query_params = Map.put(query_params, "error_description", description)

    query_params =
      if state do
        Map.put(query_params, "state", state)
      else
        query_params
      end

    new_query = URI.encode_query(query_params)
    final_uri = %{uri | query: new_query} |> URI.to_string()

    conn
    |> put_resp_header("location", final_uri)
    |> send_resp(302, "")
  end

  defp build_redirect_uri_vo(uri_string) do
    # Create a RedirectUri value object
    case RedirectUri.new(uri_string) do
      {:ok, redirect_uri} -> redirect_uri
      # Fallback to struct if validation fails
      {:error, _} -> %RedirectUri{value: uri_string}
    end
  end
end
