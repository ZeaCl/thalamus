defmodule Thalamus.Application.UseCases.ManageEnvironments do
  @moduledoc """
  Use cases for creating, updating, listing, and managing organization environments.

  SOLID Principles Applied:
  - Single Responsibility: Manages organization environment workflows
  - Dependency Inversion: Relies on EnvironmentRepository and OrganizationRepository ports
  """

  alias Thalamus.Domain.Entities.Environment

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLEnvironmentRepository,
    PostgreSQLOrganizationRepository
  }

  @type deps :: %{
          optional(:env_repo) => module(),
          optional(:org_repo) => module()
        }

  @doc """
  Lists all environments for an organization.
  """
  def list_environments(org_id, filters \\ %{}, deps \\ default_deps()) do
    repo = get_env_repo(deps)
    repo.list_by_organization(org_id, filters)
  end

  @doc """
  Gets an environment by slug or ID within an organization.
  """
  def get_environment(org_id, slug_or_id, deps \\ default_deps()) do
    repo = get_env_repo(deps)

    case repo.get_by_slug(org_id, slug_or_id) do
      {:ok, env} ->
        {:ok, env}

      {:error, :not_found} ->
        # If not found by slug, try by ID if it's a valid UUID
        case Ecto.UUID.cast(slug_or_id) do
          {:ok, uuid} ->
            case repo.get(uuid) do
              {:ok, %Environment{organization_id: env_org_id} = env} ->
                norm_org_id = normalize_org_id(org_id)
                norm_env_org_id = normalize_org_id(env_org_id)

                if norm_org_id == norm_env_org_id do
                  {:ok, env}
                else
                  {:error, :not_found}
                end

              {:error, _} ->
                {:error, :not_found}
            end

          :error ->
            {:error, :not_found}
        end
    end
  end

  @doc """
  Creates a new dynamic environment for an organization.
  """
  def create_environment(org_id, attrs, deps \\ default_deps()) do
    repo = get_env_repo(deps)

    attrs =
      attrs
      |> atomize_keys()
      |> Map.put(:organization_id, normalize_org_id(org_id))

    repo.create(attrs)
  end

  @doc """
  Updates an existing environment.
  """
  def update_environment(org_id, slug_or_id, attrs, deps \\ default_deps()) do
    repo = get_env_repo(deps)
    attrs = atomize_keys(attrs)

    with {:ok, env} <- get_environment(org_id, slug_or_id, deps) do
      # If setting is_default to true, use set_default repository method
      is_default = Map.get(attrs, :is_default)

      if is_default == true and not env.is_default do
        case repo.set_default(org_id, env.id) do
          {:ok, default_env} ->
            # Apply other field updates if present
            other_attrs = Map.drop(attrs, [:is_default])

            if other_attrs != %{} do
              updated_env = %{
                default_env
                | name: Map.get(other_attrs, :name, default_env.name),
                  type: Map.get(other_attrs, :type, default_env.type),
                  status: Map.get(other_attrs, :status, default_env.status),
                  description: Map.get(other_attrs, :description, default_env.description)
              }

              repo.save(updated_env)
            else
              {:ok, default_env}
            end

          error ->
            error
        end
      else
        updated_env = %{
          env
          | name: Map.get(attrs, :name, env.name),
            type: Map.get(attrs, :type, env.type),
            status: Map.get(attrs, :status, env.status),
            description: Map.get(attrs, :description, env.description)
        }

        repo.save(updated_env)
      end
    end
  end

  @doc """
  Deletes or archives an environment (with guard checks).
  """
  def delete_environment(org_id, slug_or_id, opts \\ [], deps \\ default_deps()) do
    repo = get_env_repo(deps)
    force = Keyword.get(opts, :force, false)

    with {:ok, env} <- get_environment(org_id, slug_or_id, deps) do
      cond do
        env.is_default ->
          {:error, :cannot_delete_default_environment}

        env.type == :production and not force ->
          {:error, :cannot_delete_production_environment}

        true ->
          repo.archive(env.id)
      end
    end
  end

  @doc """
  Seeds the default base environments for a new organization.
  Creates 'production' (default), 'staging', and 'development'.
  """
  def seed_default_environments(org_id, deps \\ default_deps()) do
    repo = get_env_repo(deps)
    norm_org_id = normalize_org_id(org_id)

    base_envs = [
      %{
        organization_id: norm_org_id,
        slug: "production",
        name: "Producción",
        type: :production,
        is_default: true,
        status: :active,
        description: "Ambiente de producción por defecto"
      },
      %{
        organization_id: norm_org_id,
        slug: "staging",
        name: "Staging QA",
        type: :staging,
        is_default: false,
        status: :active,
        description: "Ambiente de pruebas y pre-entrega"
      },
      %{
        organization_id: norm_org_id,
        slug: "development",
        name: "Desarrollo",
        type: :development,
        is_default: false,
        status: :active,
        description: "Ambiente de desarrollo local y pruebas de integración"
      }
    ]

    results =
      Enum.map(base_envs, fn env_attrs ->
        case repo.get_by_slug(norm_org_id, env_attrs.slug) do
          {:ok, existing} -> {:ok, existing}
          {:error, :not_found} -> repo.create(env_attrs)
        end
      end)

    {:ok, results}
  end

  # Helpers

  defp default_deps do
    %{
      env_repo: PostgreSQLEnvironmentRepository,
      org_repo: PostgreSQLOrganizationRepository
    }
  end

  defp get_env_repo(deps), do: Map.get(deps, :env_repo, PostgreSQLEnvironmentRepository)

  defp normalize_org_id(nil), do: nil

  defp normalize_org_id(org_id) when is_binary(org_id) do
    String.replace_prefix(org_id, "org_", "")
  end

  defp normalize_org_id(%Thalamus.Domain.ValueObjects.OrganizationId{} = id) do
    to_string(id) |> String.replace_prefix("org_", "")
  end

  defp normalize_org_id(other), do: to_string(other)

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      {key, value} -> {key, value}
    end)
  end
end
