defmodule Thalamus.Application.UseCases.ManageEnvironments do
  @moduledoc """
  Use cases for creating, updating, listing, and managing organization environments.

  SOLID Principles Applied:
  - Single Responsibility: Manages organization environment workflows
  - Dependency Inversion: Relies on EnvironmentRepository port
  """

  alias Thalamus.Domain.Entities.Environment
  alias Thalamus.Infrastructure.Repositories.PostgreSQLEnvironmentRepository

  @type deps :: %{
          optional(:env_repo) => module()
        }

  @default_environment_templates [
    %{
      slug: "production",
      name: "Producción",
      type: :production,
      is_default: true,
      status: :active,
      description: "Ambiente de producción por defecto"
    },
    %{
      slug: "staging",
      name: "Staging QA",
      type: :staging,
      is_default: false,
      status: :active,
      description: "Ambiente de pruebas y pre-entrega"
    },
    %{
      slug: "development",
      name: "Desarrollo",
      type: :development,
      is_default: false,
      status: :active,
      description: "Ambiente de desarrollo local y pruebas de integración"
    }
  ]

  @doc """
  Lists all environments for an organization.
  """
  @spec list_environments(term(), map(), deps()) :: {:ok, [Environment.t()]} | {:error, term()}
  def list_environments(org_id, filters \\ %{}, deps \\ default_deps()) do
    repo = get_env_repo(deps)
    repo.list_by_organization(org_id, filters)
  end

  @doc """
  Gets an environment by slug or ID within an organization.
  """
  @spec get_environment(term(), String.t(), deps()) ::
          {:ok, Environment.t()} | {:error, :not_found}
  def get_environment(org_id, slug_or_id, deps \\ default_deps()) do
    repo = get_env_repo(deps)
    norm_org_id = normalize_org_id(org_id)

    with {:error, :not_found} <- repo.get_by_slug(norm_org_id, slug_or_id),
         {:ok, uuid} <- Ecto.UUID.cast(slug_or_id),
         {:ok, %Environment{organization_id: env_org_id} = env} <- repo.get(uuid),
         true <- norm_org_id == normalize_org_id(env_org_id) do
      {:ok, env}
    else
      {:ok, env} -> {:ok, env}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Creates a new dynamic environment for an organization.
  """
  @spec create_environment(term(), map(), deps()) :: {:ok, Environment.t()} | {:error, term()}
  def create_environment(org_id, attrs, deps \\ default_deps()) do
    repo = get_env_repo(deps)

    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put(:organization_id, normalize_org_id(org_id))

    repo.create(attrs)
  end

  @doc """
  Updates an existing environment.
  """
  @spec update_environment(term(), String.t(), map(), deps()) ::
          {:ok, Environment.t()} | {:error, term()}
  def update_environment(org_id, slug_or_id, attrs, deps \\ default_deps()) do
    repo = get_env_repo(deps)
    attrs_map = normalize_attrs(attrs)

    with {:ok, env} <- get_environment(org_id, slug_or_id, deps),
         {:ok, env} <- maybe_set_default(env, org_id, attrs_map, repo),
         {:ok, updated_env} <- Environment.update(env, attrs_map) do
      repo.save(updated_env)
    end
  end

  @doc """
  Deletes or archives an environment (with guard checks).
  """
  @spec delete_environment(term(), String.t(), keyword(), deps()) ::
          {:ok, Environment.t()} | {:error, term()}
  def delete_environment(org_id, slug_or_id, opts \\ [], deps \\ default_deps()) do
    repo = get_env_repo(deps)
    force? = Keyword.get(opts, :force, false)

    with {:ok, env} <- get_environment(org_id, slug_or_id, deps),
         :ok <- validate_deletable(env, force?) do
      repo.archive(env.id)
    end
  end

  @doc """
  Seeds the default base environments for a new organization.
  Creates 'production' (default), 'staging', and 'development'.
  """
  @spec seed_default_environments(term(), deps()) :: {:ok, list()} | {:error, term()}
  def seed_default_environments(org_id, deps \\ default_deps()) do
    repo = get_env_repo(deps)
    norm_org_id = normalize_org_id(org_id)

    results =
      Enum.map(@default_environment_templates, fn template ->
        attrs = Map.put(template, :organization_id, norm_org_id)

        case repo.get_by_slug(norm_org_id, template.slug) do
          {:ok, existing} -> {:ok, existing}
          {:error, :not_found} -> repo.create(attrs)
        end
      end)

    {:ok, results}
  end

  # Helpers

  defp default_deps do
    %{
      env_repo: PostgreSQLEnvironmentRepository
    }
  end

  defp get_env_repo(deps), do: Map.get(deps, :env_repo, PostgreSQLEnvironmentRepository)

  defp maybe_set_default(env, org_id, %{is_default: true}, repo) when not env.is_default do
    repo.set_default(org_id, env.id)
  end

  defp maybe_set_default(env, _org_id, _attrs, _repo), do: {:ok, env}

  defp validate_deletable(%Environment{is_default: true}, _force),
    do: {:error, :cannot_delete_default_environment}

  defp validate_deletable(%Environment{type: :production}, false),
    do: {:error, :cannot_delete_production_environment}

  defp validate_deletable(%Environment{}, _force), do: :ok

  defp normalize_org_id(nil), do: nil

  defp normalize_org_id(org_id) when is_binary(org_id) do
    String.replace_prefix(org_id, "org_", "")
  end

  defp normalize_org_id(%Thalamus.Domain.ValueObjects.OrganizationId{} = id) do
    to_string(id) |> String.replace_prefix("org_", "")
  end

  defp normalize_org_id(other), do: to_string(other)

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) ->
        try do
          {String.to_existing_atom(k), v}
        rescue
          ArgumentError -> {k, v}
        end

      {k, v} ->
        {k, v}
    end)
  end

  defp normalize_attrs(other), do: other
end
