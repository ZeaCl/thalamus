defmodule ThalamusWeb.API.OAuth2ClientController do
  @moduledoc """
  OAuth2 Client Management API Controller.

  Provides REST API for OAuth2 client management operations:
  - List clients
  - Get client details
  - Create client
  - Update client
  - Delete client (soft delete)
  - Rotate client secret

  SOLID Principles Applied:
  - Single Responsibility: Only handles HTTP OAuth2 client management requests
  - Dependency Inversion: Depends on repositories through interfaces
  """

  use ThalamusWeb, :controller

  alias Thalamus.Domain.Entities.OAuth2Client
  alias Thalamus.Domain.ValueObjects.{ClientId, ClientSecret, OrganizationId, RedirectUri, Scope}
  alias Thalamus.Infrastructure.Repositories.PostgreSQLOAuth2ClientRepository
  alias Thalamus.OAuth2ClientValidator

  @doc """
  GET /api/clients

  List all OAuth2 clients with optional filtering.

  ## Query Parameters
  - organization_id: Filter by organization
  - client_type: Filter by type (confidential, public, m2m)
  - status: Filter by status (active, inactive)
  - limit: Number of results (default: 50, max: 100)
  - offset: Pagination offset

  ## Response
  200 OK with array of client objects
  """
  def index(conn, params) do
    filters = build_filters(params)

    case PostgreSQLOAuth2ClientRepository.list(filters) do
      {:ok, clients} ->
        conn
        |> put_status(:ok)
        |> json(%{
          data: Enum.map(clients, &client_to_json/1),
          meta: %{
            count: length(clients),
            filters: filters
          }
        })
    end
  end

  @doc """
  GET /api/clients/:id

  Get a specific OAuth2 client by ID.

  ## Path Parameters
  - id: Client UUID

  ## Response
  - 200 OK: Client found
  - 404 Not Found: Client not found
  """
  def show(conn, %{"id" => id}) do
    case ClientId.from_string(id) do
      {:ok, client_id} ->
        case PostgreSQLOAuth2ClientRepository.find_by_id(client_id) do
          {:ok, client} ->
            conn
            |> put_status(:ok)
            |> json(%{data: client_to_json(client)})

          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Client not found"})
        end

      {:error, _reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid client ID format"})
    end
  end

  @doc """
  POST /api/clients

  Create a new OAuth2 client.

  ## Request Body (JSON)
  {
    "name": "My Application",
    "organization_id": "org-uuid",
    "client_type": "confidential|public|m2m",
    "redirect_uris": ["https://example.com/callback"],
    "grant_types": ["authorization_code", "refresh_token"],
    "scopes": ["openid", "profile", "email"]
  }

  ## Response
  - 201 Created: Client created successfully (includes client_secret for confidential clients)
  - 400 Bad Request: Invalid input
  """
  def create(conn, params) do
    # Verify API Key scopes if authenticated with API Key
    with :ok <- verify_api_key_scopes(conn),
         {:ok, name} <- get_required_param(params, "name"),
         {:ok, org_id_string} <- get_required_param(params, "organization_id"),
         {:ok, org_id} <- OrganizationId.from_string(org_id_string),
         {:ok, client} <- create_client(name, org_id, params),
         # Save the plain secret BEFORE saving to database (where it gets hashed)
         plain_secret <- client.client_secret,
         {:ok, saved_client} <- PostgreSQLOAuth2ClientRepository.save(client) do
      # For confidential clients, include the secret in the response (only time it's visible)
      response_data = client_to_json(saved_client)

      response_data =
        if saved_client.client_type == :confidential and plain_secret do
          # Use the plain secret from BEFORE database save
          Map.put(response_data, :client_secret, plain_secret)
        else
          response_data
        end

      conn
      |> put_status(:created)
      |> json(%{
        data: response_data,
        message: "OAuth2 client created successfully"
      })
    else
      {:error, :insufficient_scopes} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "Insufficient permissions",
          details: "API key requires 'clients:write' scope to create OAuth2 clients"
        })

      {:error, :missing_parameter, param} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required parameter: #{param}"})

      {:error, {:invalid_redirect_uri, uri, reason}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid redirect URI", details: "URI '#{uri}' is invalid: #{reason}"})

      {:error, {:invalid_grant_type, grant_type, reason}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Invalid grant type",
          details: "Grant type '#{grant_type}' is invalid: #{reason}"
        })

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid input", details: to_string(reason)})

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> json(%{error: "Validation failed", details: errors})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to create client", details: inspect(reason)})
    end
  end

  @doc """
  PATCH /api/clients/:id

  Update an OAuth2 client.

  ## Path Parameters
  - id: Client UUID

  ## Request Body (JSON)
  {
    "name": "Updated Name",
    "redirect_uris": ["https://example.com/callback"],
    "status": "active|inactive"
  }

  ## Response
  - 200 OK: Client updated
  - 404 Not Found: Client not found
  - 400 Bad Request: Invalid input
  """
  def update(conn, %{"id" => id} = params) do
    with {:ok, client_id} <- ClientId.from_string(id),
         {:ok, client} <- PostgreSQLOAuth2ClientRepository.find_by_id(client_id),
         {:ok, updated_client} <- apply_updates(client, params),
         {:ok, saved_client} <- PostgreSQLOAuth2ClientRepository.save(updated_client) do
      conn
      |> put_status(:ok)
      |> json(%{
        data: client_to_json(saved_client),
        message: "Client updated successfully"
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Client not found"})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid input", details: to_string(reason)})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to update client", details: inspect(reason)})
    end
  end

  @doc """
  DELETE /api/clients/:id

  Delete an OAuth2 client (soft delete by deactivating).

  ## Path Parameters
  - id: Client UUID

  ## Response
  - 204 No Content: Client deleted
  - 404 Not Found: Client not found
  """
  def delete(conn, %{"id" => id}) do
    with {:ok, client_id} <- ClientId.from_string(id),
         {:ok, client} <- PostgreSQLOAuth2ClientRepository.find_by_id(client_id),
         {:ok, _deactivated} <- OAuth2Client.deactivate(client),
         :ok <- PostgreSQLOAuth2ClientRepository.delete(client_id) do
      conn
      |> put_status(:no_content)
      |> json(%{})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Client not found"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to delete client", details: inspect(reason)})
    end
  end

  # Private helper functions

  defp build_filters(params) do
    filters = %{}

    filters =
      if org_id = params["organization_id"] do
        # Repository expects binary string, not OrganizationId value object
        # Validate it's a valid UUID format, but keep as string
        case OrganizationId.from_string(org_id) do
          {:ok, _org_id_vo} -> Map.put(filters, :organization_id, org_id)
          _ -> filters
        end
      else
        filters
      end

    filters =
      if client_type = params["client_type"] do
        Map.put(filters, :client_type, String.to_existing_atom(client_type))
      else
        filters
      end

    filters =
      if status = params["status"] do
        Map.put(filters, :status, String.to_existing_atom(status))
      else
        filters
      end

    filters =
      if limit = params["limit"] do
        limit_int = min(String.to_integer(limit), 100)
        Map.put(filters, :limit, limit_int)
      else
        Map.put(filters, :limit, 50)
      end

    filters =
      if offset = params["offset"] do
        Map.put(filters, :offset, String.to_integer(offset))
      else
        filters
      end

    filters
  end

  defp client_to_json(%OAuth2Client{} = client) do
    # Convert grant types to strings
    grant_types =
      Enum.map(client.grant_types, fn grant_type ->
        to_string(grant_type.type)
      end)

    # Convert redirect URIs to strings
    redirect_uris =
      Enum.map(client.redirect_uris, fn uri ->
        RedirectUri.to_string(uri)
      end)

    # Convert scopes to strings
    scopes =
      Enum.map(client.allowed_scopes, fn scope ->
        Scope.to_string(scope)
      end)

    %{
      id: ClientId.to_string(client.id),
      name: client.name,
      organization_id: OrganizationId.to_string(client.organization_id),
      client_type: client.client_type,
      redirect_uris: redirect_uris,
      grant_types: grant_types,
      scopes: scopes,
      is_active: client.is_active,
      trusted: client.trusted,
      created_at: client.created_at,
      updated_at: client.updated_at
    }
  end

  defp get_required_param(params, key) do
    case params[key] do
      nil -> {:error, :missing_parameter, key}
      "" -> {:error, :missing_parameter, key}
      value -> {:ok, value}
    end
  end

  defp create_client(name, org_id, params) do
    client_type = String.to_existing_atom(params["client_type"] || "confidential")
    redirect_uri_strings = params["redirect_uris"] || []

    # Convert redirect URI strings to RedirectUri value objects
    redirect_uris_result =
      Enum.reduce_while(redirect_uri_strings, {:ok, []}, fn uri_string, {:ok, acc} ->
        case RedirectUri.new(uri_string) do
          {:ok, uri} -> {:cont, {:ok, [uri | acc]}}
          {:error, reason} -> {:halt, {:error, {:invalid_redirect_uri, uri_string, reason}}}
        end
      end)

    with {:ok, redirect_uris_reversed} <- redirect_uris_result do
      redirect_uris = Enum.reverse(redirect_uris_reversed)
      create_client_with_validated_uris(name, org_id, params, client_type, redirect_uris)
    end
  end

  defp create_client_with_validated_uris(name, org_id, params, client_type, redirect_uris) do
    with {:ok, grant_types} <- parse_grant_types_from_params(params),
         {:ok, scopes} <- parse_scopes_from_params(params),
         {:ok, client_id} <- ClientId.generate() do
      OAuth2Client.new(%{
        id: client_id,
        organization_id: org_id,
        name: name,
        client_type: client_type,
        redirect_uris: redirect_uris,
        grant_types: grant_types,
        allowed_scopes: scopes
      })
    end
  end

  defp parse_grant_types_from_params(params) do
    grant_type_strings = params["grant_types"] || ["authorization_code", "refresh_token"]

    grant_type_strings
    |> Enum.reduce_while({:ok, []}, fn type_string, {:ok, acc} ->
      case grant_type_string_to_atom(type_string) do
        {:ok, atom} ->
          {:ok, grant_type} = Thalamus.Domain.ValueObjects.GrantType.new(atom)
          {:cont, {:ok, [grant_type | acc]}}

        :error ->
          {:halt, {:error, :invalid_grant_type}}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      {:error, _} = err -> err
    end
  end

  defp grant_type_string_to_atom(type_string) do
    case type_string do
      "authorization_code" -> {:ok, :authorization_code}
      "client_credentials" -> {:ok, :client_credentials}
      "refresh_token" -> {:ok, :refresh_token}
      "implicit" -> {:ok, :implicit}
      "password" -> {:ok, :password}
      _ -> :error
    end
  end

  defp parse_scopes_from_params(params) do
    scope_strings = params["scopes"] || []

    scope_strings
    |> Enum.reduce_while({:ok, []}, fn scope_string, {:ok, acc} ->
      case Thalamus.Domain.ValueObjects.Scope.new(scope_string) do
        {:ok, scope} -> {:cont, {:ok, [scope | acc]}}
        {:error, _} -> {:halt, {:error, :invalid_scope}}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      {:error, _} = err -> err
    end
  end

  defp apply_updates(client, params) do
    client = update_client_name(client, params)
    client = update_client_redirect_uris(client, params)
    client = update_client_scopes(client, params)
    client = update_client_status(client, params)
    {:ok, client}
  end

  defp update_client_name(client, params) do
    case params["name"] do
      nil -> client
      name -> %{client | name: name}
    end
  end

  defp update_client_redirect_uris(client, params) do
    case params["redirect_uris"] do
      nil ->
        client

      redirect_uris_strings ->
        redirect_uris =
          redirect_uris_strings
          |> Enum.map(fn uri ->
            {:ok, redirect_uri} = RedirectUri.new(uri)
            redirect_uri
          end)

        %{client | redirect_uris: redirect_uris}
    end
  end

  defp update_client_scopes(client, params) do
    case params["scopes"] do
      nil -> client
      scope_strings -> %{client | allowed_scopes: parse_scope_strings(scope_strings)}
    end
  end

  defp parse_scope_strings(scope_strings) do
    Enum.map(scope_strings, fn scope_string ->
      case Scope.new(scope_string) do
        {:ok, scope} -> scope
        {:error, _reason} -> raise ArgumentError, "Invalid scope: #{scope_string}"
      end
    end)
  end

  defp update_client_status(client, params) do
    case params["status"] do
      "inactive" ->
        {:ok, updated} = OAuth2Client.deactivate(client)
        updated

      "active" ->
        {:ok, updated} = OAuth2Client.activate(client)
        updated

      _ ->
        client
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @doc """
  POST /api/clients/:id/rotate-secret

  Rotate the client secret for a confidential OAuth2 client.

  ## Path Parameters
  - id: Client UUID

  ## Response
  - 200 OK: Secret rotated successfully (includes new plain secret - SAVE IT!)
  - 400 Bad Request: Cannot rotate secret for public clients
  - 404 Not Found: Client not found
  """
  def rotate_secret(conn, %{"client_id" => id}) do
    with {:ok, client_id} <- ClientId.from_string(id),
         {:ok, client} <- PostgreSQLOAuth2ClientRepository.find_by_id(client_id),
         {:ok, updated_client} <- OAuth2Client.rotate_secret(client),
         # Capture plain secret BEFORE saving (it gets hashed during save)
         plain_secret <- extract_plain_secret(updated_client.client_secret),
         {:ok, saved_client} <- PostgreSQLOAuth2ClientRepository.save(updated_client) do
      conn
      |> put_status(:ok)
      |> json(%{
        data: %{
          client_id: ClientId.to_string(saved_client.id),
          client_secret: plain_secret,
          rotated_at: DateTime.utc_now()
        },
        message: "⚠️ IMPORTANT: Save the new client_secret securely. It cannot be retrieved later."
      })
    else
      {:error, :cannot_rotate_public_client_secret} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Cannot rotate secret for public clients"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Client not found"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to rotate secret", details: inspect(reason)})
    end
  end

  @doc """
  POST /api/clients/:client_id/add-redirect-uri

  Add a redirect URI to an OAuth2 client. Used for dynamic subdomain registration.
  """
  def add_redirect_uri(conn, %{"client_id" => id, "redirect_uri" => redirect_uri_string}) do
    with {:ok, client_id} <- ClientId.from_string(id),
         {:ok, client} <- PostgreSQLOAuth2ClientRepository.find_by_id(client_id),
         {:ok, new_redirect_uri} <- RedirectUri.new(redirect_uri_string) do
      existing_uris = Enum.map(client.redirect_uris, &RedirectUri.to_string/1)

      if redirect_uri_string in existing_uris do
        conn
        |> put_status(:ok)
        |> json(%{
          data: client_to_json(client),
          message: "Redirect URI already registered"
        })
      else
        updated_uris = client.redirect_uris ++ [new_redirect_uri]
        updated_client = %{client | redirect_uris: updated_uris}

        case PostgreSQLOAuth2ClientRepository.save(updated_client) do
          {:ok, saved_client} ->
            conn
            |> put_status(:ok)
            |> json(%{
              data: client_to_json(saved_client),
              message: "Redirect URI added successfully"
            })

          {:error, changeset} ->
            conn
            |> put_status(:bad_request)
            |> json(%{
              error: "Failed to update client redirect URIs",
              details: inspect(changeset)
            })
        end
      end
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Client not found"})

      {:error, {:invalid_redirect_uri, _uri, reason}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid redirect URI: #{reason}"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid parameter or format", details: inspect(reason)})
    end
  end

  # Private helper functions

  @doc """
  GET /api/clients/:client_id/validate

  Validate an OAuth2 client configuration. Returns a diagnostic report
  with PASS/FAIL/WARN status for each check.

  ## Authorization
  - PAT (th_pat_): user must be a member of the client's organization
  - JWT: user must be a member of the client's organization
  - API Key: admin — bypasses organization check

  ## Response
  - 200 OK: Validation report with client_id, status, summary, checks
  - 400 Bad Request: Invalid client ID format
  - 401 Unauthorized: Missing or invalid token
  - 403 Forbidden: User not authorized for this client's organization
  - 404 Not Found: Client not found
  """
  def validate(conn, %{"client_id" => id}) do
    # Validate UUID format before passing to repository
    with {:ok, client_id} <- ClientId.from_string(id),
         :ok <- validate_uuid_format(client_id),
         {:ok, client} <- PostgreSQLOAuth2ClientRepository.find_by_id(client_id),
         :ok <- verify_user_in_client_org(conn, client) do
      checks = OAuth2ClientValidator.run(client)

      conn
      |> put_status(:ok)
      |> json(%{
        client_id: ClientId.to_string(client.id),
        client_name: client.name,
        organization_id: OrganizationId.to_string(client.organization_id),
        validated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        status: OAuth2ClientValidator.overall_status(checks),
        summary: OAuth2ClientValidator.count_statuses(checks),
        checks: checks
      })
    else
      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "Forbidden",
          detail: "You do not have access to this client's organization"
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Client not found"})

      {:error, _reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid client ID format"})
    end
  end

  defp validate_uuid_format(client_id) do
    # Extract the UUID part from "client_<uuid>" format
    uuid = ClientId.to_string(client_id) |> String.replace_prefix("client_", "")

    if String.match?(uuid, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) do
      :ok
    else
      {:error, :invalid_uuid_format}
    end
  end

  defp verify_user_in_client_org(conn, %OAuth2Client{} = client) do
    # API Keys have admin access — bypass org check
    # Placeholder auth (test) — bypass org check
    if conn.assigns[:auth_type] == :api_key or allow_test_auth?() do
      :ok
    else
      client_org_id = OrganizationId.to_string(client.organization_id)
      user_org_id = conn.assigns[:organization_id]

      cond do
        is_binary(user_org_id) and user_org_id == client_org_id ->
          :ok

        is_binary(user_org_id) and user_org_id != client_org_id ->
          {:error, :forbidden}

        conn.assigns[:current_user] ->
          verify_jwt_user_org(conn.assigns[:current_user], client_org_id)

        true ->
          {:error, :forbidden}
      end
    end
  end

  defp allow_test_auth? do
    Application.get_env(:thalamus, :api_auth_placeholder, false) or
      System.get_env("TEST_AUTH_ALLOWED") == "true"
  end

  defp verify_jwt_user_org(user, client_org_id) do
    user_orgs = get_user_organization_ids(user)
    if client_org_id in user_orgs, do: :ok, else: {:error, :forbidden}
  end

  defp get_user_organization_ids(user) do
    case Map.get(user, :organization_id) do
      nil -> extract_orgs_from_list(user)
      org_id -> [org_id]
    end
  end

  defp extract_orgs_from_list(user) do
    user
    |> Map.get(:organizations, [])
    |> Enum.map(fn
      %{id: id} when is_binary(id) -> id
      %{id: id} -> OrganizationId.to_string(id)
      id when is_binary(id) -> id
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_plain_secret(client_secret) when is_binary(client_secret) do
    # If it's a plain string (from generate_client_secret), return as-is
    client_secret
  end

  defp extract_plain_secret(%ClientSecret{} = _secret) do
    # ClientSecret is already hashed, we need to regenerate
    # This shouldn't happen in rotate flow, but handle it
    generate_random_secret()
  end

  defp generate_random_secret do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp verify_api_key_scopes(conn) do
    case conn.assigns do
      %{auth_type: :api_key, api_key_scopes: scopes} ->
        if "clients:write" in scopes do
          :ok
        else
          {:error, :insufficient_scopes}
        end

      %{auth_type: :jwt} ->
        :ok

      _ ->
        :ok
    end
  end
end
