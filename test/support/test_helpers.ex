defmodule Thalamus.TestHelpers do
  @moduledoc """
  Helper functions for tests.
  """

  alias Thalamus.Domain.Entities.OAuth2Client
  alias Thalamus.Domain.ValueObjects.{ClientId, OrganizationId, GrantType, RedirectUri, Scope}

  @doc """
  Creates an OAuth2 client for testing with a simplified API.

  ## Examples

      iex> {:ok, org_id} = OrganizationId.generate()
      iex> {:ok, client} = create_test_client("Test Client", org_id, ["openid", "profile"])
  """
  def create_test_client(name, org_id, scopes, opts \\ []) do
    redirect_uris = Keyword.get(opts, :redirect_uris, ["http://localhost:3000/callback"])

    grant_types_list =
      Keyword.get(opts, :grant_types, [:authorization_code, :refresh_token, :client_credentials])

    client_type = Keyword.get(opts, :client_type, :confidential)

    with {:ok, client_id} <- ClientId.generate(),
         {:ok, grant_types} <- parse_grant_types(grant_types_list),
         {:ok, parsed_redirect_uris} <- parse_redirect_uris(redirect_uris),
         {:ok, parsed_scopes} <- parse_scopes(scopes) do
      # Generate client secret for confidential clients if not provided
      # Use plain text secret - repository will hash it automatically
      client_secret =
        case client_type do
          :confidential ->
            Keyword.get(opts, :client_secret, "test_secret_123")

          :public ->
            nil
        end

      OAuth2Client.new(%{
        id: client_id,
        organization_id: org_id,
        name: name,
        client_type: client_type,
        grant_types: grant_types,
        redirect_uris: parsed_redirect_uris,
        allowed_scopes: parsed_scopes,
        description: Keyword.get(opts, :description),
        client_secret: client_secret
      })
    end
  end

  defp parse_grant_types(grant_types_list) do
    results =
      Enum.map(grant_types_list, fn
        :authorization_code -> GrantType.authorization_code()
        :client_credentials -> GrantType.client_credentials()
        :refresh_token -> GrantType.refresh_token()
        :implicit -> GrantType.implicit()
        :password -> GrantType.password()
      end)

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil -> {:ok, Enum.map(results, fn {:ok, grant} -> grant end)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_redirect_uris(uris) do
    results = Enum.map(uris, &RedirectUri.new/1)

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil -> {:ok, Enum.map(results, fn {:ok, uri} -> uri end)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_scopes(scopes) when is_list(scopes) do
    results =
      Enum.map(scopes, fn
        scope when is_binary(scope) -> Scope.new(scope)
        scope when is_atom(scope) -> Scope.new(Atom.to_string(scope))
      end)

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil -> {:ok, Enum.map(results, fn {:ok, scope} -> scope end)}
      {:error, reason} -> {:error, reason}
    end
  end
end
