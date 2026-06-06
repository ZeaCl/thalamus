defmodule Thalamus.Application.UseCases.ResolveAgentSecret do
  @moduledoc """
  Resolves the correct secret for an agent based on priorities (Org vs User).
  """

  @doc """
  Resolves a secret given an organization ID and a user ID.
  Options can dictate if user secrets are preferred over org secrets.
  """
  def execute(provider, org_id, user_id, opts \\ [], deps \\ default_deps()) do
    prefer_user? = Keyword.get(opts, :prefer_user, false)

    if prefer_user? do
      resolve_preferring_user(provider, org_id, user_id, deps)
    else
      resolve_preferring_org(provider, org_id, user_id, deps)
    end
  end

  defp resolve_preferring_user(provider, org_id, user_id, deps) do
    case deps.secret_repo.get_by_owner_and_provider("user", user_id, provider) do
      {:ok, secret} ->
        {:ok, secret}

      {:error, :not_found} ->
        # Fallback to org
        deps.secret_repo.get_by_owner_and_provider("organization", org_id, provider)
    end
  end

  defp resolve_preferring_org(provider, org_id, user_id, deps) do
    case deps.secret_repo.get_by_owner_and_provider("organization", org_id, provider) do
      {:ok, secret} ->
        {:ok, secret}

      {:error, :not_found} ->
        # Fallback to user
        deps.secret_repo.get_by_owner_and_provider("user", user_id, provider)
    end
  end

  defp default_deps do
    %{
      secret_repo: Thalamus.Infrastructure.Repositories.PostgreSQLSecretRepository
    }
  end
end
