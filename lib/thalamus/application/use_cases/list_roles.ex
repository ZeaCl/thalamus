defmodule Thalamus.Application.UseCases.ListRoles do
  @moduledoc """
  Use case for listing all roles in an organization.

  SOLID Principles:
  - Single Responsibility: Only handles role listing
  - Dependency Inversion: Depends on ports, not implementations
  """

  @type deps :: %{
          required(:role_repository) => module()
        }

  @type request :: %{
          organization_id: binary()
        }

  @doc """
  Lists all roles for an organization.

  ## Examples

      iex> ListRoles.execute(%{organization_id: "org_123"}, deps)
      {:ok, [%Role{}, %Role{}]}
  """
  @spec execute(request(), deps()) :: {:ok, list()}
  def execute(%{organization_id: organization_id}, deps) do
    deps.role_repository.list_by_organization(organization_id)
  end
end
