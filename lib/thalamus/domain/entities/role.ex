defmodule Thalamus.Domain.Entities.Role do
  @moduledoc """
  Role Entity - Aggregate for managing user permissions via roles.

  A Role is a named collection of scopes that can be assigned to multiple users
  within an organization. Users inherit all scopes from their assigned roles.

  SOLID Principles:
  - Single Responsibility: Manages role state and validation
  - Open/Closed: Extensible via new validation rules
  - Dependency Inversion: Uses Permission value object for scope validation
  """

  alias Thalamus.Domain.ValueObjects.Permission

  @type t :: %__MODULE__{
          id: binary() | nil,
          organization_id: binary(),
          name: String.t(),
          description: String.t() | nil,
          scopes: [String.t()],
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :organization_id,
    :name,
    :description,
    :scopes,
    :created_at,
    :updated_at
  ]

  @max_name_length 100
  @max_description_length 500

  @doc """
  Creates a new Role entity.

  ## Examples

      iex> Role.new(%{
      ...>   organization_id: "org_abc123",
      ...>   name: "Developer",
      ...>   description: "Read and write code",
      ...>   scopes: ["read:code", "write:code"]
      ...> })
      {:ok, %Role{name: "Developer", scopes: ["read:code", "write:code"]}}

      iex> Role.new(%{organization_id: "org_abc", name: "", scopes: []})
      {:error, :invalid_name}
  """
  @spec new(map()) :: {:ok, t()} | {:error, atom()}
  def new(attrs) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    role = %__MODULE__{
      id: Map.get(attrs, :id),
      organization_id: attrs[:organization_id],
      name: Map.get(attrs, :name, "") |> String.trim(),
      description: Map.get(attrs, :description),
      scopes: Map.get(attrs, :scopes, []),
      created_at: Map.get(attrs, :created_at, now),
      updated_at: Map.get(attrs, :updated_at, now)
    }

    case validate(role) do
      :ok -> {:ok, role}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates role scopes.

  Returns a new Role entity with updated scopes and timestamp.

  ## Examples

      iex> {:ok, role} = Role.new(%{organization_id: "org_abc", name: "Dev", scopes: ["read:code"]})
      iex> Role.update_scopes(role, ["read:code", "write:code"])
      {:ok, %Role{scopes: ["read:code", "write:code"]}}
  """
  @spec update_scopes(t(), [String.t()]) :: {:ok, t()} | {:error, atom()}
  def update_scopes(%__MODULE__{} = role, new_scopes) when is_list(new_scopes) do
    updated_role = %{
      role
      | scopes: new_scopes,
        updated_at: DateTime.truncate(DateTime.utc_now(), :second)
    }

    case validate_scopes(new_scopes) do
      :ok -> {:ok, updated_role}
      {:error, reason} -> {:error, reason}
    end
  end

  def update_scopes(_, _), do: {:error, :invalid_scopes}

  @doc """
  Adds a scope to the role.

  ## Examples

      iex> {:ok, role} = Role.new(%{organization_id: "org_abc", name: "Dev", scopes: ["read:code"]})
      iex> Role.add_scope(role, "write:code")
      {:ok, %Role{scopes: ["read:code", "write:code"]}}
  """
  @spec add_scope(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def add_scope(%__MODULE__{scopes: scopes} = role, new_scope) do
    case Permission.new(new_scope) do
      {:ok, _permission} ->
        if new_scope in scopes do
          {:ok, role}
        else
          update_scopes(role, scopes ++ [new_scope])
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Removes a scope from the role.

  ## Examples

      iex> {:ok, role} = Role.new(%{organization_id: "org_abc", name: "Dev", scopes: ["read:code", "write:code"]})
      iex> Role.remove_scope(role, "write:code")
      {:ok, %Role{scopes: ["read:code"]}}
  """
  @spec remove_scope(t(), String.t()) :: {:ok, t()}
  def remove_scope(%__MODULE__{scopes: scopes} = role, scope_to_remove) do
    new_scopes = Enum.reject(scopes, fn s -> s == scope_to_remove end)
    updated_role = %{
      role
      | scopes: new_scopes,
        updated_at: DateTime.truncate(DateTime.utc_now(), :second)
    }

    {:ok, updated_role}
  end

  # Private functions

  defp validate(%__MODULE__{} = role) do
    with :ok <- validate_organization_id(role.organization_id),
         :ok <- validate_name(role.name),
         :ok <- validate_description(role.description),
         :ok <- validate_scopes(role.scopes) do
      :ok
    end
  end

  defp validate_organization_id(nil), do: {:error, :missing_organization_id}
  defp validate_organization_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  defp validate_organization_id(_), do: {:error, :invalid_organization_id}

  defp validate_name(name) when is_binary(name) and byte_size(name) > 0 do
    if String.length(name) <= @max_name_length do
      :ok
    else
      {:error, :name_too_long}
    end
  end

  defp validate_name(_), do: {:error, :invalid_name}

  defp validate_description(nil), do: :ok

  defp validate_description(desc) when is_binary(desc) do
    if String.length(desc) <= @max_description_length do
      :ok
    else
      {:error, :description_too_long}
    end
  end

  defp validate_description(_), do: {:error, :invalid_description}

  defp validate_scopes(scopes) when is_list(scopes) do
    Enum.reduce_while(scopes, :ok, fn scope, _acc ->
      case Permission.new(scope) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_scopes(_), do: {:error, :invalid_scopes}
end

# Protocol implementations
defimpl String.Chars, for: Thalamus.Domain.Entities.Role do
  def to_string(%{name: name}), do: "Role<#{name}>"
end

defimpl Jason.Encoder, for: Thalamus.Domain.Entities.Role do
  def encode(%Thalamus.Domain.Entities.Role{} = role, opts) do
    %{
      id: role.id,
      organization_id: role.organization_id,
      name: role.name,
      description: role.description,
      scopes: role.scopes,
      created_at: role.created_at,
      updated_at: role.updated_at
    }
    |> Jason.Encode.map(opts)
  end
end
