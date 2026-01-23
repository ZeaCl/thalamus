defmodule Thalamus.Application.UseCases.GetUserRolesTest do
  use ExUnit.Case, async: true
  import Mox

  alias Thalamus.Application.UseCases.GetUserRoles
  alias Thalamus.Domain.Entities.Role

  setup :verify_on_exit!

  @deps %{
    role_repository: Thalamus.MockRoleRepository
  }

  describe "execute/2" do
    test "successfully gets all roles assigned to user" do
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      role1 = %Role{
        id: Ecto.UUID.generate(),
        organization_id: org_id,
        name: "Developer",
        scopes: ["read:code", "write:code"],
        description: "Dev role"
      }

      role2 = %Role{
        id: Ecto.UUID.generate(),
        organization_id: org_id,
        name: "Reviewer",
        scopes: ["review:pr"],
        description: "Reviewer role"
      }

      request = %{user_id: user_id}

      Thalamus.MockRoleRepository
      |> expect(:get_user_roles, fn ^user_id -> {:ok, [role1, role2]} end)

      assert {:ok, roles} = GetUserRoles.execute(request, @deps)
      assert length(roles) == 2
      assert Enum.any?(roles, &(&1.name == "Developer"))
      assert Enum.any?(roles, &(&1.name == "Reviewer"))
    end

    test "returns empty list when user has no roles" do
      user_id = Ecto.UUID.generate()
      request = %{user_id: user_id}

      Thalamus.MockRoleRepository
      |> expect(:get_user_roles, fn ^user_id -> {:ok, []} end)

      assert {:ok, []} = GetUserRoles.execute(request, @deps)
    end

    test "returns roles with complete information" do
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      role = %Role{
        id: Ecto.UUID.generate(),
        organization_id: org_id,
        name: "Admin",
        scopes: ["admin:all", "user:manage"],
        description: "Administrator role"
      }

      request = %{user_id: user_id}

      Thalamus.MockRoleRepository
      |> expect(:get_user_roles, fn ^user_id -> {:ok, [role]} end)

      assert {:ok, [returned_role]} = GetUserRoles.execute(request, @deps)
      assert returned_role.id == role.id
      assert returned_role.name == "Admin"
      assert returned_role.scopes == ["admin:all", "user:manage"]
      assert returned_role.description == "Administrator role"
    end
  end
end
