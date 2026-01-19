defmodule Thalamus.Domain.Entities.OAuth2Client do
  @moduledoc """
  OAuth2Client Entity - Aggregate Root for OAuth2 client applications.

  Represents an OAuth2 client application with its configuration,
  allowed grant types, redirect URIs, and scopes.

  SOLID Principles Applied:
  - Single Responsibility: Manages OAuth2 client configuration and validation
  - Open/Closed: Extensible for new OAuth2 features without modification
  - Dependency Inversion: Uses Value Objects for data validation
  """

  alias Thalamus.Domain.ValueObjects.{
    ClientId,
    OrganizationId,
    GrantType,
    RedirectUri,
    Scope
  }

  @type client_type :: :confidential | :public
  @type t :: %__MODULE__{
          id: ClientId.t(),
          organization_id: OrganizationId.t(),
          name: String.t(),
          description: String.t() | nil,
          client_type: client_type(),
          client_secret: String.t() | nil,
          grant_types: [GrantType.t()],
          redirect_uris: [RedirectUri.t()],
          allowed_scopes: [Scope.t()],
          is_active: boolean(),
          trusted: boolean(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :organization_id,
    :name,
    :description,
    :client_type,
    :client_secret,
    :grant_types,
    :redirect_uris,
    :allowed_scopes,
    :is_active,
    :trusted,
    :created_at,
    :updated_at
  ]

  @doc """
  Creates a new OAuth2Client.

  ## Examples

      iex> {:ok, client_id} = ClientId.generate()
      iex> {:ok, org_id} = OrganizationId.generate()
      iex> {:ok, grant} = GrantType.authorization_code()
      iex> {:ok, redirect} = RedirectUri.new("https://app.example.com/callback")
      iex> {:ok, scope} = Scope.new("openid")
      iex> OAuth2Client.new(%{
      ...>   id: client_id,
      ...>   organization_id: org_id,
      ...>   name: "My App",
      ...>   client_type: :confidential,
      ...>   grant_types: [grant],
      ...>   redirect_uris: [redirect],
      ...>   allowed_scopes: [scope]
      ...> })
      {:ok, %OAuth2Client{name: "My App", ...}}
  """
  def new(
        %{
          id: id,
          organization_id: org_id,
          name: name,
          client_type: client_type,
          grant_types: grant_types,
          redirect_uris: redirect_uris,
          allowed_scopes: allowed_scopes
        } = attrs
      )
      when client_type in [:confidential, :public] do
    now = DateTime.utc_now()

    client_secret =
      if client_type == :confidential do
        Map.get(attrs, :client_secret, generate_client_secret())
      else
        nil
      end

    client = %__MODULE__{
      id: id,
      organization_id: org_id,
      name: name,
      description: Map.get(attrs, :description),
      client_type: client_type,
      client_secret: client_secret,
      grant_types: grant_types,
      redirect_uris: redirect_uris,
      allowed_scopes: allowed_scopes,
      is_active: Map.get(attrs, :is_active, true),
      trusted: Map.get(attrs, :trusted, false),
      created_at: now,
      updated_at: now
    }

    case validate_client(client) do
      :ok -> {:ok, client}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, :missing_required_fields}

  @doc """
  Creates a confidential client (server-side application).

  ## Examples

      iex> {:ok, org_id} = OrganizationId.generate()
      iex> OAuth2Client.create_confidential("My Server App", org_id)
      {:ok, %OAuth2Client{client_type: :confidential, client_secret: "..."}}
  """
  def create_confidential(name, %OrganizationId{} = org_id) do
    with {:ok, client_id} <- ClientId.generate(),
         {:ok, grant} <- GrantType.authorization_code(),
         {:ok, scope} <- Scope.new("openid") do
      new(%{
        id: client_id,
        organization_id: org_id,
        name: name,
        client_type: :confidential,
        grant_types: [grant],
        redirect_uris: [],
        allowed_scopes: [scope]
      })
    end
  end

  @doc """
  Creates a public client (mobile/SPA application).

  ## Examples

      iex> {:ok, org_id} = OrganizationId.generate()
      iex> OAuth2Client.create_public("My Mobile App", org_id)
      {:ok, %OAuth2Client{client_type: :public, client_secret: nil}}
  """
  def create_public(name, %OrganizationId{} = org_id) do
    with {:ok, client_id} <- ClientId.generate(),
         {:ok, grant} <- GrantType.authorization_code(),
         {:ok, scope} <- Scope.new("openid") do
      new(%{
        id: client_id,
        organization_id: org_id,
        name: name,
        client_type: :public,
        grant_types: [grant],
        redirect_uris: [],
        allowed_scopes: [scope]
      })
    end
  end

  @doc """
  Creates a machine-to-machine client.

  ## Examples

      iex> {:ok, org_id} = OrganizationId.generate()
      iex> OAuth2Client.create_m2m("Background Service", org_id)
      {:ok, %OAuth2Client{grant_types: [%GrantType{type: :client_credentials}]}}
  """
  def create_m2m(name, %OrganizationId{} = org_id) do
    with {:ok, client_id} <- ClientId.generate(),
         {:ok, grant} <- GrantType.client_credentials(),
         {:ok, scope} <- Scope.new("zea:read") do
      new(%{
        id: client_id,
        organization_id: org_id,
        name: name,
        client_type: :confidential,
        grant_types: [grant],
        redirect_uris: [],
        allowed_scopes: [scope]
      })
    end
  end

  @doc """
  Verifies a client secret.

  ## Examples

      iex> {:ok, client} = OAuth2Client.create_confidential("App", org_id)
      iex> OAuth2Client.verify_secret(client, client.client_secret)
      :ok

      iex> OAuth2Client.verify_secret(client, "wrong_secret")
      {:error, :invalid_client_secret}
  """
  def verify_secret(%__MODULE__{client_secret: nil}, _secret) do
    {:error, :public_client_no_secret}
  end

  def verify_secret(
        %__MODULE__{client_secret: %Thalamus.Domain.ValueObjects.ClientSecret{} = stored_secret},
        provided_secret
      )
      when is_binary(provided_secret) do
    # Use ClientSecret value object's verify method for bcrypt comparison
    if Thalamus.Domain.ValueObjects.ClientSecret.verify(stored_secret, provided_secret) do
      :ok
    else
      {:error, :invalid_client_secret}
    end
  end

  def verify_secret(%__MODULE__{client_secret: stored_secret}, provided_secret)
      when is_binary(stored_secret) and is_binary(provided_secret) do
    # Fallback for legacy string-based secrets (for backward compatibility)
    if secure_compare(stored_secret, provided_secret) do
      :ok
    else
      {:error, :invalid_client_secret}
    end
  end

  def verify_secret(_, _), do: {:error, :invalid_client_secret}

  @doc """
  Rotates the client secret.

  ## Examples

      iex> OAuth2Client.rotate_secret(client)
      {:ok, %OAuth2Client{client_secret: new_secret}}
  """
  def rotate_secret(%__MODULE__{client_type: :public}) do
    {:error, :cannot_rotate_public_client_secret}
  end

  def rotate_secret(%__MODULE__{client_type: :confidential} = client) do
    new_secret = generate_client_secret()
    {:ok, %{client | client_secret: new_secret, updated_at: DateTime.utc_now()}}
  end

  @doc """
  Adds a grant type to the client.

  ## Examples

      iex> {:ok, grant} = GrantType.refresh_token()
      iex> OAuth2Client.add_grant_type(client, grant)
      {:ok, %OAuth2Client{grant_types: [_, _]}}
  """
  def add_grant_type(%__MODULE__{grant_types: grants} = client, %GrantType{} = new_grant) do
    if grant_type_exists?(client, new_grant) do
      {:error, :grant_type_already_exists}
    else
      {:ok, %{client | grant_types: [new_grant | grants], updated_at: DateTime.utc_now()}}
    end
  end

  def add_grant_type(_, _), do: {:error, :invalid_grant_type}

  @doc """
  Removes a grant type from the client.

  ## Examples

      iex> OAuth2Client.remove_grant_type(client, :implicit)
      {:ok, %OAuth2Client{}}
  """
  def remove_grant_type(%__MODULE__{grant_types: grants} = client, grant_type_atom) do
    new_grants = Enum.reject(grants, fn grant -> grant.type == grant_type_atom end)

    if length(new_grants) == 0 do
      {:error, :cannot_remove_last_grant_type}
    else
      {:ok, %{client | grant_types: new_grants, updated_at: DateTime.utc_now()}}
    end
  end

  @doc """
  Checks if client supports a grant type.

  ## Examples

      iex> OAuth2Client.supports_grant_type?(client, :authorization_code)
      true
  """
  def supports_grant_type?(%__MODULE__{grant_types: grants}, grant_type_atom) do
    Enum.any?(grants, fn grant -> grant.type == grant_type_atom end)
  end

  @doc """
  Adds a redirect URI to the client.

  ## Examples

      iex> {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      iex> OAuth2Client.add_redirect_uri(client, uri)
      {:ok, %OAuth2Client{redirect_uris: [_, _]}}
  """
  def add_redirect_uri(%__MODULE__{redirect_uris: uris} = client, new_uri)
      when is_binary(new_uri) do
    # Normalize URIs to strings for comparison (handles both strings and RedirectUri structs)
    existing_uris = Enum.map(uris, fn
      %RedirectUri{} = uri -> RedirectUri.to_string(uri)
      uri when is_binary(uri) -> uri
    end)

    if new_uri in existing_uris do
      {:error, :redirect_uri_already_exists}
    else
      {:ok, %{client | redirect_uris: [new_uri | uris], updated_at: DateTime.utc_now()}}
    end
  end

  @doc """
  Removes a redirect URI from the client.

  ## Examples

      iex> OAuth2Client.remove_redirect_uri(client, "https://app.example.com/callback")
      {:ok, %OAuth2Client{}}
  """
  def remove_redirect_uri(%__MODULE__{redirect_uris: uris} = client, uri_string)
      when is_binary(uri_string) do
    # Handle both strings and RedirectUri structs
    new_uris = Enum.reject(uris, fn
      %RedirectUri{} = uri -> RedirectUri.to_string(uri) == uri_string
      uri when is_binary(uri) -> uri == uri_string
    end)

    {:ok, %{client | redirect_uris: new_uris, updated_at: DateTime.utc_now()}}
  end

  @doc """
  Validates a redirect URI for this client.

  ## Examples

      iex> OAuth2Client.valid_redirect_uri?(client, "https://app.example.com/callback")
      true
  """
  def valid_redirect_uri?(%__MODULE__{redirect_uris: uris}, uri_string) do
    # redirect_uris can be either strings (from DB) or RedirectUri structs (from domain)
    Enum.any?(uris, fn
      %RedirectUri{} = uri -> RedirectUri.to_string(uri) == uri_string
      uri when is_binary(uri) -> uri == uri_string
    end)
  end

  @doc """
  Adds a scope to the client's allowed scopes.

  ## Examples

      iex> {:ok, scope} = Scope.new("profile")
      iex> OAuth2Client.add_scope(client, scope)
      {:ok, %OAuth2Client{allowed_scopes: [_, _]}}
  """
  def add_scope(%__MODULE__{allowed_scopes: scopes} = client, new_scope)
      when is_binary(new_scope) do
    # Normalize scopes to strings for comparison (handles both strings and Scope structs)
    existing_scopes = Enum.map(scopes, fn
      scope when is_binary(scope) -> scope
      scope -> Scope.to_string(scope)
    end)

    if new_scope in existing_scopes do
      {:error, :scope_already_exists}
    else
      {:ok, %{client | allowed_scopes: [new_scope | scopes], updated_at: DateTime.utc_now()}}
    end
  end

  @doc """
  Removes a scope from the client's allowed scopes.

  ## Examples

      iex> OAuth2Client.remove_scope(client, "email")
      {:ok, %OAuth2Client{}}
  """
  def remove_scope(%__MODULE__{allowed_scopes: scopes} = client, scope_string)
      when is_binary(scope_string) do
    # Handle both strings and Scope structs
    new_scopes = Enum.reject(scopes, fn
      scope when is_binary(scope) -> scope == scope_string
      scope -> Scope.to_string(scope) == scope_string
    end)

    if length(new_scopes) == 0 do
      {:error, :cannot_remove_last_scope}
    else
      {:ok, %{client | allowed_scopes: new_scopes, updated_at: DateTime.utc_now()}}
    end
  end

  @doc """
  Validates scopes for this client.

  ## Examples

      iex> OAuth2Client.valid_scopes?(client, ["openid", "profile"])
      true
  """
  def valid_scopes?(%__MODULE__{allowed_scopes: allowed}, requested_scope_strings) do
    # Handle both string scopes (from database) and Scope value objects
    allowed_strings =
      Enum.map(allowed, fn
        scope when is_binary(scope) -> scope
        scope -> Scope.to_string(scope)
      end)

    Enum.all?(requested_scope_strings, fn scope -> scope in allowed_strings end)
  end

  @doc """
  Activates the client.

  ## Examples

      iex> OAuth2Client.activate(client)
      {:ok, %OAuth2Client{is_active: true}}
  """
  def activate(%__MODULE__{} = client) do
    {:ok, %{client | is_active: true, updated_at: DateTime.utc_now()}}
  end

  @doc """
  Deactivates the client.

  ## Examples

      iex> OAuth2Client.deactivate(client)
      {:ok, %OAuth2Client{is_active: false}}
  """
  def deactivate(%__MODULE__{} = client) do
    {:ok, %{client | is_active: false, updated_at: DateTime.utc_now()}}
  end

  @doc """
  Marks client as trusted (skips consent screen).

  ## Examples

      iex> OAuth2Client.mark_trusted(client)
      {:ok, %OAuth2Client{trusted: true}}
  """
  def mark_trusted(%__MODULE__{} = client) do
    {:ok, %{client | trusted: true, updated_at: DateTime.utc_now()}}
  end

  @doc """
  Removes trusted status from client.

  ## Examples

      iex> OAuth2Client.mark_untrusted(client)
      {:ok, %OAuth2Client{trusted: false}}
  """
  def mark_untrusted(%__MODULE__{} = client) do
    {:ok, %{client | trusted: false, updated_at: DateTime.utc_now()}}
  end

  # Private functions

  defp validate_client(%__MODULE__{} = client) do
    cond do
      is_nil(client.id) ->
        {:error, :missing_client_id}

      is_nil(client.organization_id) ->
        {:error, :missing_organization_id}

      is_nil(client.name) or client.name == "" ->
        {:error, :missing_name}

      String.length(client.name) < 2 ->
        {:error, :name_too_short}

      String.length(client.name) > 100 ->
        {:error, :name_too_long}

      Enum.empty?(client.grant_types) ->
        {:error, :missing_grant_types}

      # Allow clients without scopes for M2M scenarios
      # Enum.empty?(client.allowed_scopes) ->
      #   {:error, :missing_scopes}

      client.client_type == :confidential and is_nil(client.client_secret) ->
        {:error, :confidential_client_requires_secret}

      client.client_type == :public and not is_nil(client.client_secret) ->
        {:error, :public_client_cannot_have_secret}

      true ->
        :ok
    end
  end

  defp generate_client_secret do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  # Constant-time comparison to prevent timing attacks
  defp secure_compare(a, b) when byte_size(a) == byte_size(b) do
    Plug.Crypto.secure_compare(a, b)
  end

  defp secure_compare(_, _), do: false

  defp grant_type_exists?(%__MODULE__{grant_types: grants}, %GrantType{} = new_grant) do
    Enum.any?(grants, fn grant -> grant.type == new_grant.type end)
  end
end

# Implement String.Chars protocol
defimpl String.Chars, for: Thalamus.Domain.Entities.OAuth2Client do
  def to_string(%Thalamus.Domain.Entities.OAuth2Client{name: name}) do
    "OAuth2Client<#{name}>"
  end
end

# Implement Jason.Encoder - safe serialization (no secret exposure)
defimpl Jason.Encoder, for: Thalamus.Domain.Entities.OAuth2Client do
  def encode(%Thalamus.Domain.Entities.OAuth2Client{} = client, opts) do
    %{
      id: client.id,
      name: client.name,
      client_type: client.client_type,
      grant_types: client.grant_types,
      redirect_uris: client.redirect_uris,
      allowed_scopes: client.allowed_scopes,
      is_active: client.is_active,
      trusted: client.trusted,
      created_at: client.created_at
    }
    |> Jason.Encode.map(opts)
  end
end
