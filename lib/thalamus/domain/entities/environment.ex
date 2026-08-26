defmodule Thalamus.Domain.Entities.Environment do
  @moduledoc """
  Environment Entity - Represents an isolated operational environment (dev, staging, prod, sandbox)
  within an Organization in the ZEA Thalamus IAM system.

  SOLID Principles Applied:
  - Single Responsibility: Encapsulates environment entity validation and state transitions
  - Open/Closed: Extensible types and statuses
  """

  @valid_types [:production, :staging, :development, :sandbox, :demo]
  @valid_statuses [:active, :suspended, :archived]
  @slug_regex ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/

  @type env_type :: :production | :staging | :development | :sandbox | :demo
  @type env_status :: :active | :suspended | :archived

  @type t :: %__MODULE__{
          id: binary() | nil,
          organization_id: binary(),
          slug: String.t(),
          name: String.t(),
          type: env_type(),
          is_default: boolean(),
          status: env_status(),
          description: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :organization_id,
    :slug,
    :name,
    :type,
    :is_default,
    :status,
    :description,
    :inserted_at,
    :updated_at
  ]

  @doc """
  Creates a new Environment domain entity struct with validation.
  """
  @spec new(map()) :: {:ok, t()} | {:error, atom() | {atom(), any()}}
  def new(attrs) when is_map(attrs) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    slug =
      case Map.get(attrs, :slug) || Map.get(attrs, "slug") do
        s when is_binary(s) -> String.downcase(String.trim(s))
        _ -> nil
      end

    name = Map.get(attrs, :name) || Map.get(attrs, "name")
    org_id = Map.get(attrs, :organization_id) || Map.get(attrs, "organization_id")

    raw_type = Map.get(attrs, :type) || Map.get(attrs, "type") || :development
    type = parse_type(raw_type)

    is_default =
      case Map.get(attrs, :is_default) || Map.get(attrs, "is_default") || false do
        true -> true
        "true" -> true
        _ -> false
      end

    raw_status = Map.get(attrs, :status) || Map.get(attrs, "status") || :active
    status = parse_status(raw_status)

    description = Map.get(attrs, :description) || Map.get(attrs, "description")
    id = Map.get(attrs, :id) || Map.get(attrs, "id")

    env = %__MODULE__{
      id: id,
      organization_id: org_id,
      slug: slug,
      name: name,
      type: type,
      is_default: is_default,
      status: status,
      description: description,
      inserted_at: Map.get(attrs, :inserted_at) || Map.get(attrs, "inserted_at") || now,
      updated_at: Map.get(attrs, :updated_at) || Map.get(attrs, "updated_at") || now
    }

    case validate_environment(env) do
      :ok -> {:ok, env}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates if an environment can be safely deleted.
  Production and default environments are protected against accidental deletion.
  """
  @spec can_delete?(t()) :: :ok | {:error, atom()}
  def can_delete?(%__MODULE__{is_default: true}), do: {:error, :cannot_delete_default_environment}

  def can_delete?(%__MODULE__{type: :production}),
    do: {:error, :cannot_delete_production_environment}

  def can_delete?(%__MODULE__{}), do: :ok

  @doc """
  Activates an environment.
  """
  def activate(%__MODULE__{} = env) do
    {:ok, %{env | status: :active, updated_at: DateTime.utc_now()}}
  end

  @doc """
  Suspends an environment.
  """
  def suspend(%__MODULE__{} = env) do
    {:ok, %{env | status: :suspended, updated_at: DateTime.utc_now()}}
  end

  @doc """
  Archives an environment.
  """
  def archive(%__MODULE__{} = env) do
    case can_delete?(env) do
      :ok -> {:ok, %{env | status: :archived, updated_at: DateTime.utc_now()}}
      error -> error
    end
  end

  @doc """
  Returns the list of valid environment types.
  """
  def valid_types, do: @valid_types

  @doc """
  Returns the list of valid environment statuses.
  """
  def valid_statuses, do: @valid_statuses

  # Private validation helper
  defp validate_environment(%__MODULE__{} = env) do
    cond do
      is_nil(env.organization_id) or env.organization_id == "" ->
        {:error, :missing_organization_id}

      is_nil(env.name) or env.name == "" ->
        {:error, :missing_name}

      String.length(env.name) < 2 ->
        {:error, :name_too_short}

      String.length(env.name) > 100 ->
        {:error, :name_too_long}

      is_nil(env.slug) or env.slug == "" ->
        {:error, :missing_slug}

      not String.match?(env.slug, @slug_regex) ->
        {:error, :invalid_slug_format}

      String.length(env.slug) < 2 or String.length(env.slug) > 50 ->
        {:error, :invalid_slug_length}

      env.type not in @valid_types ->
        {:error, :invalid_environment_type}

      env.status not in @valid_statuses ->
        {:error, :invalid_environment_status}

      true ->
        :ok
    end
  end

  defp parse_type(t) when is_atom(t), do: t

  defp parse_type(t) when is_binary(t) do
    try do
      String.to_existing_atom(t)
    rescue
      ArgumentError -> :invalid
    end
  end

  defp parse_type(_), do: :invalid

  defp parse_status(s) when is_atom(s), do: s

  defp parse_status(s) when is_binary(s) do
    try do
      String.to_existing_atom(s)
    rescue
      ArgumentError -> :invalid
    end
  end

  defp parse_status(_), do: :invalid
end
