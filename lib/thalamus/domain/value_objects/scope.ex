defmodule Thalamus.Domain.ValueObjects.Scope do
  @moduledoc """
  Value Object representing an OAuth2 scope.

  SOLID Principles Applied:
  - Single Responsibility: Only handles scope validation and operations
  - Open/Closed: Can be extended for different scope formats without modification
  - Interface Segregation: Provides only scope-specific operations
  """

  @type t :: %__MODULE__{
          value: String.t()
        }

  defstruct [:value]

  # Predefined standard scopes for OAuth2/OpenID Connect
  @standard_scopes [
    # OpenID Connect identity
    "openid",
    # Basic profile information
    "profile",
    # Email address
    "email",
    # Physical address
    "address",
    # Phone number
    "phone",
    # Refresh token capability
    "offline_access"
  ]

  # Custom ZEA platform scopes
  @zea_scopes [
    # Read access to ZEA resources
    "zea:read",
    # Write access to ZEA resources
    "zea:write",
    # Administrative access
    "zea:admin",
    # Access to Synapse telemetry events
    "synapse:events",
    # Access to Synapse metrics
    "synapse:metrics",
    # Access to Cortex chat API
    "cortex:chat",
    # Access to Cortex completions
    "cortex:completions",
    # Read billing information
    "billing:read",
    # Modify billing information
    "billing:write",
    # Read organization data
    "organizations:read",
    # Modify organization data
    "organizations:write"
  ]

  @all_valid_scopes @standard_scopes ++ @zea_scopes

  @doc """
  Creates a new Scope.

  ## Examples

      iex> Scope.new("read")
      {:ok, %Scope{value: "read"}}

      iex> Scope.new("openid")
      {:ok, %Scope{value: "openid"}}

      iex> Scope.new("")
      {:error, :invalid_scope}

      iex> Scope.new("invalid_scope!")
      {:error, :invalid_scope_format}
  """
  def new(value) when is_binary(value) and value != "" do
    normalized_scope = String.downcase(String.trim(value))

    case validate_format(normalized_scope) do
      :ok -> {:ok, %__MODULE__{value: normalized_scope}}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, :invalid_scope}

  @doc """
  Creates multiple scopes from a space-separated string.

  ## Examples

      iex> Scope.from_string("openid profile email")
      {:ok, [%Scope{value: "openid"}, %Scope{value: "profile"}, %Scope{value: "email"}]}

      iex> Scope.from_string("invalid_scope!")
      {:error, :invalid_scope_format}
  """
  def from_string(scopes_string) when is_binary(scopes_string) do
    scopes_string
    |> String.split(" ", trim: true)
    |> Enum.reduce_while({:ok, []}, fn scope_str, {:ok, acc} ->
      case new(scope_str) do
        {:ok, scope} -> {:cont, {:ok, [scope | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, scopes} -> {:ok, Enum.reverse(scopes)}
      error -> error
    end
  end

  def from_string(_), do: {:error, :invalid_input}

  @doc """
  Converts a list of scopes to a space-separated string.

  ## Examples

      iex> scopes = [%Scope{value: "openid"}, %Scope{value: "profile"}]
      iex> Scope.to_string(scopes)
      "openid profile"
  """
  def to_string(scopes) when is_list(scopes) do
    scopes
    |> Enum.map(& &1.value)
    |> Enum.join(" ")
  end

  def to_string(%__MODULE__{value: value}), do: value

  @doc """
  Checks if a scope is a standard OAuth2/OpenID Connect scope.

  ## Examples

      iex> scope = %Scope{value: "openid"}
      iex> Scope.standard?(scope)
      true

      iex> scope = %Scope{value: "zea:read"}
      iex> Scope.standard?(scope)
      false
  """
  def standard?(%__MODULE__{value: value}) do
    Enum.member?(@standard_scopes, value)
  end

  @doc """
  Checks if a scope is a ZEA platform specific scope.

  ## Examples

      iex> scope = %Scope{value: "zea:read"}
      iex> Scope.zea_scope?(scope)
      true

      iex> scope = %Scope{value: "openid"}
      iex> Scope.zea_scope?(scope)
      false
  """
  def zea_scope?(%__MODULE__{value: value}) do
    Enum.member?(@zea_scopes, value)
  end

  @doc """
  Checks if a scope requires special permissions.

  ## Examples

      iex> scope = %Scope{value: "zea:admin"}
      iex> Scope.requires_special_permission?(scope)
      true

      iex> scope = %Scope{value: "profile"}
      iex> Scope.requires_special_permission?(scope)
      false
  """
  def requires_special_permission?(%__MODULE__{value: value}) do
    special_permission_scopes = [
      "zea:admin",
      "billing:write",
      "organizations:write",
      "offline_access"
    ]

    Enum.member?(special_permission_scopes, value)
  end

  @doc """
  Gets the resource type from a scope.

  ## Examples

      iex> scope = %Scope{value: "zea:read"}
      iex> Scope.resource_type(scope)
      "zea"

      iex> scope = %Scope{value: "synapse:events"}
      iex> Scope.resource_type(scope)
      "synapse"

      iex> scope = %Scope{value: "openid"}
      iex> Scope.resource_type(scope)
      "identity"
  """
  def resource_type(%__MODULE__{value: value}) do
    case String.split(value, ":") do
      [resource, _action] -> resource
      [scope] when scope in @standard_scopes -> "identity"
      _ -> "unknown"
    end
  end

  @doc """
  Gets the action from a scope.

  ## Examples

      iex> scope = %Scope{value: "zea:read"}
      iex> Scope.action(scope)
      "read"

      iex> scope = %Scope{value: "openid"}
      iex> Scope.action(scope)
      "access"
  """
  def action(%__MODULE__{value: value}) do
    case String.split(value, ":") do
      [_resource, action] -> action
      [scope] when scope in @standard_scopes -> "access"
      _ -> "unknown"
    end
  end

  @doc """
  Lists all valid scopes for the ZEA platform.

  ## Examples

      iex> Scope.valid_scopes()
      ["openid", "profile", "email", ..., "zea:read", "zea:write", ...]
  """
  def valid_scopes, do: @all_valid_scopes

  # Private functions

  defp validate_format(value) do
    cond do
      String.length(value) < 1 ->
        {:error, :scope_too_short}

      String.length(value) > 100 ->
        {:error, :scope_too_long}

      not String.match?(value, ~r/^[a-zA-Z0-9_.:-]+$/) ->
        {:error, :invalid_scope_format}

      not Enum.member?(@all_valid_scopes, value) ->
        {:error, :unknown_scope}

      true ->
        :ok
    end
  end
end

# Implement String.Chars protocol for easy conversion
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.Scope do
  def to_string(%Thalamus.Domain.ValueObjects.Scope{value: value}), do: value
end

# Implement Jason.Encoder for JSON serialization
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.Scope do
  def encode(%Thalamus.Domain.ValueObjects.Scope{value: value}, opts) do
    Jason.Encode.string(value, opts)
  end
end
