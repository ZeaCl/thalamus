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

  # Standard OIDC scopes (always valid, cannot be changed)
  @standard_oidc_scopes [
    "openid",
    "profile",
    "email",
    "address",
    "phone",
    "offline_access"
  ]

  # Default custom scopes - GENERIC examples
  # Override these via configuration for your specific application:
  #   config :thalamus, :oauth2_scopes, %{
  #     custom_scopes: ["api:read", "api:write", "admin:all"],
  #     restricted_scopes: ["admin:all", "offline_access"]
  #   }
  @default_custom_scopes [
    "api:read",
    "api:write",
    "api:admin",
    "data:read",
    "data:write",
    "webhooks:manage",
    "billing:read",
    "billing:write"
  ]

  # Default restricted scopes requiring special permission
  @default_restricted_scopes [
    "api:admin",
    "billing:write",
    "offline_access"
  ]

  # Configuration helpers
  defp get_scope_config do
    Application.get_env(:thalamus, :oauth2_scopes, default_scope_config())
  end

  defp default_scope_config do
    %{
      standard_scopes: @standard_oidc_scopes,
      custom_scopes: @default_custom_scopes,
      restricted_scopes: @default_restricted_scopes
    }
  end

  defp get_standard_scopes do
    config = get_scope_config()
    Map.get(config, :standard_scopes, @standard_oidc_scopes)
  end

  defp get_custom_scopes do
    config = get_scope_config()
    Map.get(config, :custom_scopes, @default_custom_scopes)
  end

  defp get_restricted_scopes do
    config = get_scope_config()
    Map.get(config, :restricted_scopes, @default_restricted_scopes)
  end

  defp get_all_valid_scopes do
    get_standard_scopes() ++ get_custom_scopes()
  end

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

      iex> scope = %Scope{value: "api:read"}
      iex> Scope.standard?(scope)
      false
  """
  def standard?(%__MODULE__{value: value}) do
    Enum.member?(get_standard_scopes(), value)
  end

  @doc """
  Checks if a scope is a custom application-specific scope.

  ## Examples

      iex> scope = %Scope{value: "api:read"}
      iex> Scope.custom_scope?(scope)
      true

      iex> scope = %Scope{value: "openid"}
      iex> Scope.custom_scope?(scope)
      false
  """
  def custom_scope?(%__MODULE__{value: value}) do
    Enum.member?(get_custom_scopes(), value)
  end

  @doc deprecated: "Use custom_scope?/1 instead"
  def zea_scope?(%__MODULE__{} = scope) do
    custom_scope?(scope)
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
    Enum.member?(get_restricted_scopes(), value)
  end

  @doc """
  Gets the resource type from a scope.

  ## Examples

      iex> scope = %Scope{value: "api:read"}
      iex> Scope.resource_type(scope)
      "api"

      iex> scope = %Scope{value: "synapse:events"}
      iex> Scope.resource_type(scope)
      "synapse"

      iex> scope = %Scope{value: "openid"}
      iex> Scope.resource_type(scope)
      "identity"
  """
  def resource_type(%__MODULE__{value: value}) do
    case String.split(value, ":") do
      [resource, _action] ->
        resource

      [scope] ->
        if Enum.member?(get_standard_scopes(), scope) do
          "identity"
        else
          "unknown"
        end

      _ ->
        "unknown"
    end
  end

  @doc """
  Gets the action from a scope.

  ## Examples

      iex> scope = %Scope{value: "api:read"}
      iex> Scope.action(scope)
      "read"

      iex> scope = %Scope{value: "openid"}
      iex> Scope.action(scope)
      "access"
  """
  def action(%__MODULE__{value: value}) do
    case String.split(value, ":") do
      [_resource, action] ->
        action

      [scope] ->
        if Enum.member?(get_standard_scopes(), scope) do
          "access"
        else
          "unknown"
        end

      _ ->
        "unknown"
    end
  end

  @doc """
  Lists all valid scopes (standard + custom).

  ## Examples

      iex> Scope.valid_scopes()
      ["openid", "profile", "email", ..., "app:read", "app:write", ...]
  """
  def valid_scopes, do: get_all_valid_scopes()

  # Private functions

  defp validate_format(value) do
    cond do
      String.length(value) < 1 ->
        {:error, :scope_too_short}

      String.length(value) > 100 ->
        {:error, :scope_too_long}

      not String.match?(value, ~r/^[a-zA-Z0-9_:-]+$/) ->
        {:error, :invalid_scope_format}

      not Enum.member?(get_all_valid_scopes(), value) ->
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
