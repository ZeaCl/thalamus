defmodule Thalamus.Application.UseCases.GetUserRoles do
  @moduledoc """
  Use case for getting all roles assigned to a user.

  SOLID Principles:
  - Single Responsibility: Only handles retrieving user roles
  - Dependency Inversion: Depends on ports, not implementations
  """

  @type deps :: %{
          required(:role_repository) => module()
        }

  @type request :: %{
          user_id: binary()
        }

  @doc """
  Gets all roles assigned to a user.

  ## Examples

      iex> GetUserRoles.execute(%{user_id: "user_123"}, deps)
      {:ok, [%Role{}, %Role{}]}
  """
  @spec execute(request(), deps()) :: {:ok, list()}
  def execute(%{user_id: user_id}, deps) do
    deps.role_repository.get_user_roles(user_id)
  end
end
