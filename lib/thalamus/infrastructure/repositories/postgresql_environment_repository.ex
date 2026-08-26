defmodule Thalamus.Infrastructure.Repositories.PostgreSQLEnvironmentRepository do
  @moduledoc """
  PostgreSQL implementation of the EnvironmentRepository port.

  Handles persistence of Environment entities using Ecto.
  """
  @behaviour Thalamus.Application.Ports.EnvironmentRepository

  import Ecto.Query
  alias Thalamus.Repo
  alias Thalamus.Domain.Entities.Environment
  alias Thalamus.Infrastructure.Persistence.Schemas.EnvironmentSchema

  @impl true
  def create(attrs) when is_map(attrs) do
    is_atom_map = Enum.all?(Map.keys(attrs), &is_atom/1)
    org_id = normalize_org_id(attrs[:organization_id] || attrs["organization_id"])

    attrs =
      if is_atom_map do
        Map.put(attrs, :organization_id, org_id)
      else
        attrs = Map.delete(attrs, :organization_id)
        Map.put(attrs, "organization_id", org_id)
      end

    is_default =
      case attrs[:is_default] || attrs["is_default"] do
        true -> true
        "true" -> true
        _ -> false
      end

    if is_default do
      Ecto.Multi.new()
      |> Ecto.Multi.update_all(
        :unset_defaults,
        from(e in EnvironmentSchema, where: e.organization_id == ^org_id),
        set: [is_default: false]
      )
      |> Ecto.Multi.insert(
        :create_env,
        EnvironmentSchema.create_changeset(%EnvironmentSchema{}, attrs)
      )
      |> Repo.transaction()
      |> case do
        {:ok, %{create_env: schema}} -> {:ok, schema_to_entity(schema)}
        {:error, :create_env, changeset, _} -> {:error, changeset}
        {:error, _step, reason, _} -> {:error, reason}
      end
    else
      %EnvironmentSchema{}
      |> EnvironmentSchema.create_changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, schema} -> {:ok, schema_to_entity(schema)}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  @impl true
  def save(%Environment{} = env) do
    org_id = normalize_org_id(env.organization_id)

    attrs = %{
      organization_id: org_id,
      slug: env.slug,
      name: env.name,
      type: env.type,
      is_default: env.is_default,
      status: env.status,
      description: env.description
    }

    if env.id do
      case Repo.get(EnvironmentSchema, env.id) do
        nil ->
          attrs = Map.put(attrs, :id, env.id)
          create(attrs)

        schema ->
          if env.is_default and not schema.is_default do
            set_default(org_id, env.id)
          else
            schema
            |> EnvironmentSchema.update_changeset(attrs)
            |> Repo.update()
            |> case do
              {:ok, updated} -> {:ok, schema_to_entity(updated)}
              {:error, changeset} -> {:error, changeset}
            end
          end
      end
    else
      create(attrs)
    end
  end

  @impl true
  def get(id) when is_binary(id) do
    if valid_uuid?(id) do
      case Repo.get(EnvironmentSchema, id) do
        nil -> {:error, :not_found}
        schema -> {:ok, schema_to_entity(schema)}
      end
    else
      {:error, :not_found}
    end
  end

  @impl true
  def get_by_slug(org_id, slug) when is_binary(slug) do
    norm_org_id = normalize_org_id(org_id)

    if valid_uuid?(norm_org_id) do
      norm_slug = String.downcase(String.trim(slug))

      query =
        from e in EnvironmentSchema,
          where: e.organization_id == ^norm_org_id and e.slug == ^norm_slug

      case Repo.one(query) do
        nil -> {:error, :not_found}
        schema -> {:ok, schema_to_entity(schema)}
      end
    else
      {:error, :not_found}
    end
  end

  @impl true
  def get_default(org_id) do
    norm_org_id = normalize_org_id(org_id)

    if valid_uuid?(norm_org_id) do
      query =
        from e in EnvironmentSchema,
          where:
            e.organization_id == ^norm_org_id and e.is_default == true and e.status != :archived,
          limit: 1

      case Repo.one(query) do
        nil ->
          # Fallback to production slug if not marked default
          fallback_query =
            from e in EnvironmentSchema,
              where:
                e.organization_id == ^norm_org_id and e.slug == "production" and
                  e.status != :archived,
              limit: 1

          case Repo.one(fallback_query) do
            nil -> {:error, :not_found}
            schema -> {:ok, schema_to_entity(schema)}
          end

        schema ->
          {:ok, schema_to_entity(schema)}
      end
    else
      {:error, :not_found}
    end
  end

  @impl true
  def list_by_organization(org_id, filters \\ %{}) do
    norm_org_id = normalize_org_id(org_id)

    if valid_uuid?(norm_org_id) do
      filters_map = if is_list(filters), do: Enum.into(filters, %{}), else: filters

      include_archived =
        case Map.get(filters_map, :include_archived) || Map.get(filters_map, "include_archived") do
          true -> true
          "true" -> true
          _ -> false
        end

      status_filter = Map.get(filters_map, :status) || Map.get(filters_map, "status")

      query =
        from e in EnvironmentSchema,
          where: e.organization_id == ^norm_org_id,
          order_by: [desc: e.is_default, asc: e.name]

      query =
        cond do
          status_filter != nil ->
            s =
              if is_binary(status_filter),
                do: String.to_existing_atom(status_filter),
                else: status_filter

            from e in query, where: e.status == ^s

          not include_archived ->
            from e in query, where: e.status != :archived

          true ->
            query
        end

      entities =
        Repo.all(query)
        |> Enum.map(&schema_to_entity/1)

      {:ok, entities}
    else
      {:ok, []}
    end
  end

  @impl true
  def set_default(org_id, environment_id) when is_binary(environment_id) do
    norm_org_id = normalize_org_id(org_id)

    if valid_uuid?(norm_org_id) and valid_uuid?(environment_id) do
      Ecto.Multi.new()
      |> Ecto.Multi.update_all(
        :unset_all,
        from(e in EnvironmentSchema, where: e.organization_id == ^norm_org_id),
        set: [is_default: false]
      )
      |> Ecto.Multi.update(
        :set_new_default,
        fn _ ->
          case Repo.get_by(EnvironmentSchema, id: environment_id, organization_id: norm_org_id) do
            nil ->
              EnvironmentSchema.update_changeset(%EnvironmentSchema{}, %{})
              |> Ecto.Changeset.add_error(:id, "environment not found in organization")

            schema ->
              EnvironmentSchema.update_changeset(schema, %{is_default: true, status: :active})
          end
        end
      )
      |> Repo.transaction()
      |> case do
        {:ok, %{set_new_default: updated_schema}} ->
          {:ok, schema_to_entity(updated_schema)}

        {:error, :set_new_default, changeset, _} ->
          {:error, changeset}

        {:error, _step, reason, _} ->
          {:error, reason}
      end
    else
      {:error, :not_found}
    end
  end

  @impl true
  def delete(id) when is_binary(id) do
    if valid_uuid?(id) do
      case Repo.get(EnvironmentSchema, id) do
        nil ->
          {:error, :not_found}

        schema ->
          case Repo.delete(schema) do
            {:ok, _} -> :ok
            {:error, changeset} -> {:error, changeset}
          end
      end
    else
      {:error, :not_found}
    end
  end

  @impl true
  def archive(id) when is_binary(id) do
    if valid_uuid?(id) do
      case Repo.get(EnvironmentSchema, id) do
        nil ->
          {:error, :not_found}

        schema ->
          schema
          |> EnvironmentSchema.update_changeset(%{status: :archived, is_default: false})
          |> Repo.update()
          |> case do
            {:ok, updated} -> {:ok, schema_to_entity(updated)}
            {:error, changeset} -> {:error, changeset}
          end
      end
    else
      {:error, :not_found}
    end
  end

  # Helpers

  defp normalize_org_id(nil), do: nil

  defp normalize_org_id(org_id) when is_binary(org_id) do
    String.replace_prefix(org_id, "org_", "")
  end

  defp normalize_org_id(%Thalamus.Domain.ValueObjects.OrganizationId{} = id) do
    to_string(id) |> String.replace_prefix("org_", "")
  end

  defp normalize_org_id(other), do: to_string(other)

  defp schema_to_entity(%EnvironmentSchema{} = schema) do
    %Environment{
      id: schema.id,
      organization_id: schema.organization_id,
      slug: schema.slug,
      name: schema.name,
      type: schema.type,
      is_default: schema.is_default,
      status: schema.status,
      description: schema.description,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  defp valid_uuid?(nil), do: false

  defp valid_uuid?(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp valid_uuid?(_), do: false
end
