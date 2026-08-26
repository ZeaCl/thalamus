defmodule Thalamus.Application.UseCases.ResolveAgentSecret do
  @moduledoc """
  Resolves the correct secret for an agent based on priorities (Org vs User).
  """

  @doc """
  Resolves a secret given an organization ID and a user ID.
  Options can dictate if user secrets are preferred over org secrets,
  and optionally scope to an environment_id with automatic global fallback.
  """
  def execute(provider, org_id, user_id, opts \\ [], deps \\ default_deps()) do
    prefer_user? = Keyword.get(opts, :prefer_user, false)
    environment_id = Keyword.get(opts, :environment_id)
    # Normalize provider to lowercase (defense in depth — also done on write)
    provider = String.downcase(provider || "")

    if prefer_user? do
      resolve_preferring_user(provider, org_id, user_id, environment_id, deps)
    else
      resolve_preferring_org(provider, org_id, user_id, environment_id, deps)
    end
  end

  defp resolve_preferring_user(provider, org_id, user_id, env_id, deps) do
    case deps.secret_repo.get_by_owner_provider_and_env("user", user_id, provider, env_id) do
      {:ok, secret} ->
        {:ok, secret}

      {:error, :not_found} ->
        # Fallback to org
        deps.secret_repo.get_by_owner_provider_and_env("organization", org_id, provider, env_id)
    end
  end

  defp resolve_preferring_org(provider, org_id, user_id, env_id, deps) do
    case deps.secret_repo.get_by_owner_provider_and_env("organization", org_id, provider, env_id) do
      {:ok, secret} ->
        {:ok, secret}

      {:error, :not_found} ->
        # Fallback to user
        deps.secret_repo.get_by_owner_provider_and_env("user", user_id, provider, env_id)
    end
  end

  defp default_deps do
    %{
      secret_repo: Thalamus.Infrastructure.Repositories.PostgreSQLSecretRepository
    }
  end
end
