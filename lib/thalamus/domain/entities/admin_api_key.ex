defmodule Thalamus.Domain.Entities.AdminApiKey do
  @moduledoc """
  AdminApiKey Entity - Represents an administrative API key for service authentication.

  Admin API Keys allow external services to authenticate and perform administrative
  operations such as registering OAuth2 clients without manual intervention.

  SOLID Principles Applied:
  - Single Responsibility: Manages API key state and validation
  - Open/Closed: Extensible for new validation rules without modification
  - Dependency Inversion: Interfaces with repositories through ports

  ## Security Considerations

  - API keys are hashed using Bcrypt before storage (never stored in plaintext)
  - Only the key_prefix (first 12 characters) is used for lookup
  - Full API key is only returned once upon creation or rotation
  - Keys can be revoked, expired, and have scope-based permissions
  """

  @type t :: %__MODULE__{
          id: String.t(),
          key_hash: String.t(),
          key_prefix: String.t(),
          name: String.t(),
          description: String.t() | nil,
          scopes: [String.t()],
          is_active: boolean(),
          expires_at: DateTime.t() | nil,
          last_used_at: DateTime.t() | nil,
          created_by_user_id: String.t() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :key_hash,
    :key_prefix,
    :name,
    :description,
    :scopes,
    :is_active,
    :expires_at,
    :last_used_at,
    :created_by_user_id,
    :created_at,
    :updated_at
  ]

  @valid_scopes [
    "clients:read",
    "clients:write",
    "clients:delete",
    "users:read",
    "users:write",
    "organizations:read",
    "organizations:write",
    "corpus:read",
    "corpus:write"
  ]

  @doc """
  Creates a new AdminApiKey with the given attributes.

  ## Required Attributes

  - `id` - Unique identifier (UUID)
  - `key_hash` - Bcrypt hash of the full API key
  - `key_prefix` - First 13 characters of the API key for lookup
  - `name` - Human-readable name for the API key

  ## Optional Attributes

  - `description` - Detailed description of the key's purpose
  - `scopes` - List of allowed scopes (default: [])
  - `is_active` - Whether the key is active (default: true)
  - `expires_at` - Expiration timestamp (default: nil, never expires)
  - `created_by_user_id` - ID of the user who created the key

  ## Examples

      iex> AdminApiKey.new(%{
      ...>   id: "550e8400-e29b-41d4-a716-446655440000",
      ...>   key_hash: "$2b$10$...",
      ...>   key_prefix: "ak_dev_vK8mN2",
      ...>   name: "Sport Backend Registration",
      ...>   scopes: ["clients:write"]
      ...> })
      {:ok, %AdminApiKey{is_active: true, ...}}

      iex> AdminApiKey.new(%{})
      {:error, :missing_required_fields}

      iex> AdminApiKey.new(%{id: "...", key_hash: "...", key_prefix: "...", name: "...", scopes: ["invalid:scope"]})
      {:error, {:invalid_scopes, ["invalid:scope"]}}
  """
  def new(%{id: id, key_hash: key_hash, key_prefix: key_prefix, name: name} = attrs)
      when is_binary(id) and is_binary(key_hash) and is_binary(key_prefix) and is_binary(name) do
    scopes = Map.get(attrs, :scopes, [])

    with :ok <- validate_name(name),
         :ok <- validate_key_prefix(key_prefix),
         :ok <- validate_scopes(scopes) do
      now = DateTime.truncate(DateTime.utc_now(), :second)

      api_key = %__MODULE__{
        id: id,
        key_hash: key_hash,
        key_prefix: key_prefix,
        name: name,
        description: Map.get(attrs, :description),
        scopes: scopes,
        is_active: Map.get(attrs, :is_active, true),
        expires_at: Map.get(attrs, :expires_at),
        last_used_at: Map.get(attrs, :last_used_at),
        created_by_user_id: Map.get(attrs, :created_by_user_id),
        created_at: Map.get(attrs, :created_at, now),
        updated_at: Map.get(attrs, :updated_at, now)
      }

      {:ok, api_key}
    end
  end

  def new(_attrs), do: {:error, :missing_required_fields}

  @doc """
  Activates an API key.

  ## Examples

      iex> api_key = %AdminApiKey{is_active: false}
      iex> AdminApiKey.activate(api_key)
      {:ok, %AdminApiKey{is_active: true}}
  """
  def activate(%__MODULE__{} = api_key) do
    {:ok, %{api_key | is_active: true, updated_at: DateTime.truncate(DateTime.utc_now(), :second)}}
  end

  @doc """
  Deactivates (revokes) an API key.

  Deactivated keys cannot be used for authentication.

  ## Examples

      iex> api_key = %AdminApiKey{is_active: true}
      iex> AdminApiKey.deactivate(api_key)
      {:ok, %AdminApiKey{is_active: false}}
  """
  def deactivate(%__MODULE__{} = api_key) do
    {:ok, %{api_key | is_active: false, updated_at: DateTime.truncate(DateTime.utc_now(), :second)}}
  end

  @doc """
  Checks if an API key has expired.

  ## Examples

      iex> api_key = %AdminApiKey{expires_at: nil}
      iex> AdminApiKey.expired?(api_key)
      false

      iex> past = DateTime.add(DateTime.utc_now(), -3600, :second)
      iex> api_key = %AdminApiKey{expires_at: past}
      iex> AdminApiKey.expired?(api_key)
      true

      iex> future = DateTime.add(DateTime.utc_now(), 3600, :second)
      iex> api_key = %AdminApiKey{expires_at: future}
      iex> AdminApiKey.expired?(api_key)
      false
  """
  def expired?(%__MODULE__{expires_at: nil}), do: false

  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Checks if an API key can be used (is active and not expired).

  ## Examples

      iex> api_key = %AdminApiKey{is_active: true, expires_at: nil}
      iex> AdminApiKey.valid?(api_key)
      true

      iex> api_key = %AdminApiKey{is_active: false, expires_at: nil}
      iex> AdminApiKey.valid?(api_key)
      false

      iex> past = DateTime.add(DateTime.utc_now(), -3600, :second)
      iex> api_key = %AdminApiKey{is_active: true, expires_at: past}
      iex> AdminApiKey.valid?(api_key)
      false
  """
  def valid?(%__MODULE__{is_active: false}), do: false
  def valid?(%__MODULE__{} = api_key) do
    not expired?(api_key)
  end

  @doc """
  Checks if an API key has a specific scope.

  ## Examples

      iex> api_key = %AdminApiKey{scopes: ["clients:write", "clients:read"]}
      iex> AdminApiKey.has_scope?(api_key, "clients:write")
      true

      iex> api_key = %AdminApiKey{scopes: ["clients:read"]}
      iex> AdminApiKey.has_scope?(api_key, "clients:write")
      false
  """
  def has_scope?(%__MODULE__{scopes: scopes}, required_scope) do
    required_scope in scopes
  end

  @doc """
  Checks if an API key has all of the required scopes.

  ## Examples

      iex> api_key = %AdminApiKey{scopes: ["clients:write", "clients:read", "clients:delete"]}
      iex> AdminApiKey.has_scopes?(api_key, ["clients:write", "clients:read"])
      true

      iex> api_key = %AdminApiKey{scopes: ["clients:read"]}
      iex> AdminApiKey.has_scopes?(api_key, ["clients:write", "clients:read"])
      false
  """
  def has_scopes?(%__MODULE__{scopes: scopes}, required_scopes) when is_list(required_scopes) do
    Enum.all?(required_scopes, fn scope -> scope in scopes end)
  end

  @doc """
  Updates the last_used_at timestamp.

  ## Examples

      iex> api_key = %AdminApiKey{last_used_at: nil}
      iex> {:ok, updated} = AdminApiKey.mark_as_used(api_key)
      iex> is_nil(updated.last_used_at)
      false
  """
  def mark_as_used(%__MODULE__{} = api_key) do
    {:ok,
     %{api_key | last_used_at: DateTime.truncate(DateTime.utc_now(), :second), updated_at: DateTime.truncate(DateTime.utc_now(), :second)}}
  end

  @doc """
  Returns the list of valid scopes.
  """
  def valid_scopes, do: @valid_scopes

  # Private validation functions

  defp validate_name(name) when byte_size(name) < 3 do
    {:error, :name_too_short}
  end

  defp validate_name(name) when byte_size(name) > 255 do
    {:error, :name_too_long}
  end

  defp validate_name(_name), do: :ok

  defp validate_key_prefix(prefix) when byte_size(prefix) != 13 do
    {:error, :invalid_key_prefix_length}
  end

  defp validate_key_prefix(prefix) do
    if String.starts_with?(prefix, "ak_dev_") or String.starts_with?(prefix, "ak_live_") do
      :ok
    else
      {:error, :invalid_key_prefix_format}
    end
  end

  defp validate_scopes(scopes) when is_list(scopes) do
    invalid_scopes = Enum.reject(scopes, fn scope -> scope in @valid_scopes end)

    if Enum.empty?(invalid_scopes) do
      :ok
    else
      {:error, {:invalid_scopes, invalid_scopes}}
    end
  end

  defp validate_scopes(_), do: {:error, :scopes_must_be_list}
end
