defmodule Thalamus.Application.UseCases.ManageSecrets do
  @moduledoc """
  Use cases for creating, updating, and deleting secrets.
  """

  @doc """
  Creates a new secret.
  """
  def create_secret(attrs, deps \\ default_deps()) do
    deps.secret_repo.create(attrs)
  end

  @doc """
  Lists secrets by owner (user or org).
  """
  def list_by_owner(owner_type, owner_id, deps \\ default_deps()) do
    deps.secret_repo.list_by_owner(owner_type, owner_id)
  end

  @doc """
  Deletes a secret.
  """
  def delete_secret(id, deps \\ default_deps()) do
    deps.secret_repo.delete(id)
  end

  defp default_deps do
    %{
      secret_repo: Thalamus.Infrastructure.Repositories.PostgreSQLSecretRepository
    }
  end
end
