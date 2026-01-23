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

  alias Thalamus.Infrastructure.Repositories.PostgreSQLOAuth2ClientRepository
  alias Thalamus.Domain.Entities.OAuth2Client
  alias Thalamus.Domain.ValueObjects.{ClientId, OrganizationId, ClientSecret, RedirectUri, Scope}

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
        |> json(%{error: "Invalid grant type", details: "Grant type '#{grant_type}' is invalid: #{reason}"})

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

    # Parse grant types
    grant_type_strings = params["grant_types"] || ["authorization_code", "refresh_token"]

    grant_types_result =
      Enum.reduce_while(grant_type_strings, {:ok, []}, fn type_string, {:ok, acc} ->
        # Convert string to atom safely (validate against known grant types)
        type_atom =
          case type_string do
            "authorization_code" -> :authorization_code
            "client_credentials" -> :client_credentials
            "refresh_token" -> :refresh_token
            "implicit" -> :implicit
            "password" -> :password
            _ -> nil
          end

        if type_atom do
          case Thalamus.Domain.ValueObjects.GrantType.new(type_atom) do
            {:ok, grant_type} -> {:cont, {:ok, [grant_type | acc]}}
            {:error, reason} -> {:halt, {:error, {:invalid_grant_type, type_string, reason}}}
          end
        else
          {:halt, {:error, {:invalid_grant_type, type_string, :unknown_grant_type}}}
        end
      end)

    with {:ok, grant_types_reversed} <- grant_types_result do
      grant_types = Enum.reverse(grant_types_reversed)
      create_client_with_grant_types(name, org_id, params, client_type, redirect_uris, grant_types)
    end
  end

  defp create_client_with_grant_types(name, org_id, params, client_type, redirect_uris, grant_types) do

    # Convert scope strings to Scope value objects
    scope_strings = params["scopes"] || []

    scopes =
      Enum.map(scope_strings, fn scope_string ->
        case Scope.new(scope_string) do
          {:ok, scope} -> scope
          {:error, _reason} -> raise ArgumentError, "Invalid scope: #{scope_string}"
        end
      end)

    {:ok, client_id} = ClientId.generate()

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

  defp apply_updates(client, params) do
    # Apply name update if present
    client =
      if name = params["name"] do
        %{client | name: name}
      else
        client
      end

    # Apply redirect URIs update if present
    client =
      case params["redirect_uris"] do
        nil ->
          {:ok, client}

        redirect_uri_strings ->
          # Convert redirect URI strings to RedirectUri value objects
          redirect_uris_result =
            Enum.reduce_while(redirect_uri_strings, {:ok, []}, fn uri_string, {:ok, acc} ->
              case RedirectUri.new(uri_string) do
                {:ok, uri} -> {:cont, {:ok, [uri | acc]}}
                {:error, reason} -> {:halt, {:error, {:invalid_redirect_uri, uri_string, reason}}}
              end
            end)

          case redirect_uris_result do
            {:ok, redirect_uris_reversed} ->
              redirect_uris = Enum.reverse(redirect_uris_reversed)
              {:ok, %{client | redirect_uris: redirect_uris}}

            {:error, _} = error ->
              error
          end
      end

    with {:ok, client} <- client do
      apply_status_and_name(client, params)
    end
  end

  defp apply_status_and_name(client, params) do
    # Apply name update if present
    client =
      if name = params["name"] do
        %{client | name: name}
      else
        client
      end

    # Apply scopes update if present
    client =
      case params["scopes"] do
        nil ->
          client

        scope_strings ->
          # Convert scope strings to Scope value objects
          scopes =
            Enum.map(scope_strings, fn scope_string ->
              case Scope.new(scope_string) do
                {:ok, scope} -> scope
                {:error, _reason} -> raise ArgumentError, "Invalid scope: #{scope_string}"
              end
            end)

          %{client | allowed_scopes: scopes}
      end

    # Apply status update if present
    client =
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

    {:ok, client}
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

  # Private helper functions

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
