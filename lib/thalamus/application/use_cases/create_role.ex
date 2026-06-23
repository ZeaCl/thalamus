defmodule Thalamus.Application.UseCases.CreateRole do
  @moduledoc """
  Use case for creating a new role.

  SOLID Principles:
  - Single Responsibility: Only handles role creation workflow
  - Dependency Inversion: Depends on ports, not implementations
  """

  alias Thalamus.Domain.Entities.Role

  @type deps :: %{
          required(:role_repository) => module()
        }

  @type request :: %{
          organization_id: binary(),
          name: String.t(),
          description: String.t() | nil,
          scopes: [String.t()]
        }

  @doc """
  Creates a new role.

  ## Examples

      iex> request = %{
      ...>   organization_id: "org_123",
      ...>   name: "Developer",
      ...>   description: "Full dev access",
      ...>   scopes: ["read:code", "write:code"]
      ...> }
      iex> CreateRole.execute(request, deps)
      {:ok, %Role{}}
  """
  @spec execute(request(), deps()) :: {:ok, Role.t()} | {:error, atom()}
  def execute(request, deps) do
    with {:ok, role} <- Role.new(request),
         :ok <- check_duplicate_name(request.organization_id, request.name, deps),
         {:ok, saved_role} <- deps.role_repository.save(role) do
      {:ok, saved_role}
    end
  end

  defp check_duplicate_name(organization_id, name, deps) do
    case deps.role_repository.find_by_name(organization_id, name) do
      {:ok, _existing_role} -> {:error, :duplicate_role_name}
      {:error, :not_found} -> :ok
    end
  end
end
