defmodule Thalamus.Application.UseCases.ListRolesTest do
  use ExUnit.Case, async: true
  import Mox

  alias Thalamus.Application.UseCases.ListRoles
  alias Thalamus.Domain.Entities.Role

  setup :verify_on_exit!

  @deps %{
    role_repository: Thalamus.MockRoleRepository
  }

  describe "execute/2" do
    test "successfully lists all roles for organization" do
      org_id = Ecto.UUID.generate()

      role1 = %Role{
        id: Ecto.UUID.generate(),
        organization_id: org_id,
        name: "Admin",
        scopes: ["admin:all"],
        description: "Admin role"
      }

      role2 = %Role{
        id: Ecto.UUID.generate(),
        organization_id: org_id,
        name: "Developer",
        scopes: ["read:code", "write:code"],
        description: "Developer role"
      }

      request = %{organization_id: org_id}

      Thalamus.MockRoleRepository
      |> expect(:list_by_organization, fn ^org_id -> {:ok, [role1, role2]} end)

      assert {:ok, roles} = ListRoles.execute(request, @deps)
      assert length(roles) == 2
      assert Enum.any?(roles, &(&1.name == "Admin"))
      assert Enum.any?(roles, &(&1.name == "Developer"))
    end

    test "returns empty list when organization has no roles" do
      org_id = Ecto.UUID.generate()
      request = %{organization_id: org_id}

      Thalamus.MockRoleRepository
      |> expect(:list_by_organization, fn ^org_id -> {:ok, []} end)

      assert {:ok, []} = ListRoles.execute(request, @deps)
    end

    test "only returns roles for specified organization" do
      org1_id = Ecto.UUID.generate()

      role1 = %Role{
        id: Ecto.UUID.generate(),
        organization_id: org1_id,
        name: "Role1",
        scopes: ["scope1"],
        description: "Role 1"
      }

      request = %{organization_id: org1_id}

      Thalamus.MockRoleRepository
      |> expect(:list_by_organization, fn ^org1_id -> {:ok, [role1]} end)

      assert {:ok, [returned_role]} = ListRoles.execute(request, @deps)
      assert returned_role.organization_id == org1_id
    end
  end
end
