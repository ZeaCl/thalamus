defmodule Thalamus.Infrastructure.Repositories.PostgresqlRoleRepositoryTest do
  use Thalamus.DataCase, async: false

  alias Thalamus.Infrastructure.Repositories.PostgresqlRoleRepository

  alias Thalamus.Infrastructure.Persistence.Schemas.{
    RoleSchema,
    UserRoleSchema,
    UserSchema,
    OrganizationSchema
  }

  alias Thalamus.Domain.Entities.Role
  alias Thalamus.Repo

  describe "save/1" do
    test "creates a new role when id is nil" do
      org = insert_organization()

      {:ok, role} =
        Role.new(%{
          organization_id: org.id,
          name: "Developer",
          description: "Development team role",
          scopes: ["read:code", "write:code"]
        })

      assert {:ok, saved_role} = PostgresqlRoleRepository.save(role)
      assert saved_role.id != nil
      assert saved_role.name == "Developer"
      assert saved_role.description == "Development team role"
      assert saved_role.scopes == ["read:code", "write:code"]
      assert saved_role.organization_id == "org_" <> org.id
    end

    test "updates existing role when id is present" do
      org = insert_organization()
      existing = insert_role(org, "Admin", ["read:all"])

      {:ok, role} =
        Role.new(%{
          id: existing.id,
          organization_id: org.id,
          name: "Admin",
          description: "Updated description",
          scopes: ["read:all", "write:all"]
        })

      assert {:ok, updated_role} = PostgresqlRoleRepository.save(role)
      assert updated_role.id == existing.id
      assert updated_role.scopes == ["read:all", "write:all"]
      assert updated_role.description == "Updated description"
    end

    test "returns error when inserting duplicate role name in same organization" do
      org = insert_organization()
      role_name = "DuplicateTest"

      # Insert first role
      {:ok, role1} =
        Role.new(%{
          organization_id: org.id,
          name: role_name,
          scopes: ["scope:one"]
        })

      assert {:ok, _saved1} = PostgresqlRoleRepository.save(role1)

      # Try to insert second role with same name
      {:ok, role2} =
        Role.new(%{
          organization_id: org.id,
          name: role_name,
          scopes: ["scope:two"]
        })

      assert {:error, changeset} = PostgresqlRoleRepository.save(role2)
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "find_by_id/1" do
    test "returns role when found" do
      org = insert_organization()
      role = insert_role(org, "Manager", ["manage:team"])

      assert {:ok, found} = PostgresqlRoleRepository.find_by_id(role.id)
      assert found.id == role.id
      assert found.name == "Manager"
      assert found.scopes == ["manage:team"]
    end

    test "returns not_found error when role doesn't exist" do
      assert {:error, :not_found} = PostgresqlRoleRepository.find_by_id(Ecto.UUID.generate())
    end
  end

  describe "find_by_name/2" do
    test "returns role when found by name and organization" do
      org = insert_organization()
      role = insert_role(org, "Viewer", ["read:data"])

      assert {:ok, found} = PostgresqlRoleRepository.find_by_name(org.id, "Viewer")
      assert found.id == role.id
      assert found.name == "Viewer"
    end

    test "is case-insensitive" do
      org = insert_organization()
      insert_role(org, "Editor", ["edit:content"])

      assert {:ok, found} = PostgresqlRoleRepository.find_by_name(org.id, "EDITOR")
      assert found.name == "Editor"
    end

    test "returns not_found for different organization" do
      org1 = insert_organization()
      org2 = insert_organization()
      insert_role(org1, "Private", ["private:scope"])

      assert {:error, :not_found} = PostgresqlRoleRepository.find_by_name(org2.id, "Private")
    end

    test "returns not_found when role doesn't exist" do
      org = insert_organization()
      assert {:error, :not_found} = PostgresqlRoleRepository.find_by_name(org.id, "NonExistent")
    end
  end

  describe "list_by_organization/1" do
    test "returns all roles for organization" do
      org1 = insert_organization()
      org2 = insert_organization()

      role1 = insert_role(org1, "Role1", ["scope1"])
      role2 = insert_role(org1, "Role2", ["scope2"])
      _other_org_role = insert_role(org2, "Role3", ["scope3"])

      assert {:ok, roles} = PostgresqlRoleRepository.list_by_organization(org1.id)
      assert length(roles) == 2
      role_ids = Enum.map(roles, & &1.id)
      assert role1.id in role_ids
      assert role2.id in role_ids
    end

    test "returns empty list when no roles exist" do
      org = insert_organization()
      assert {:ok, []} = PostgresqlRoleRepository.list_by_organization(org.id)
    end
  end

  describe "delete/1" do
    test "deletes role and returns success" do
      org = insert_organization()
      role = insert_role(org, "ToDelete", ["scope"])

      assert {:ok, 1} = PostgresqlRoleRepository.delete(role.id)
      assert {:error, :not_found} = PostgresqlRoleRepository.find_by_id(role.id)
    end

    test "cascades to user_roles" do
      org = insert_organization()
      user = insert_user(org)
      role = insert_role(org, "RoleWithUsers", ["scope"])
      insert_user_role(user, role)

      assert Repo.get_by(UserRoleSchema, user_id: user.id, role_id: role.id) != nil
      assert {:ok, 1} = PostgresqlRoleRepository.delete(role.id)
      assert Repo.get_by(UserRoleSchema, user_id: user.id, role_id: role.id) == nil
    end

    test "returns error when role doesn't exist" do
      assert {:error, :not_found} = PostgresqlRoleRepository.delete(Ecto.UUID.generate())
    end
  end

  describe "get_user_roles/1" do
    test "returns all roles assigned to user" do
      org = insert_organization()
      user = insert_user(org)
      role1 = insert_role(org, "Role1", ["scope1"])
      role2 = insert_role(org, "Role2", ["scope2"])
      _unassigned_role = insert_role(org, "Role3", ["scope3"])

      insert_user_role(user, role1)
      insert_user_role(user, role2)

      assert {:ok, roles} = PostgresqlRoleRepository.get_user_roles(user.id)
      assert length(roles) == 2
      role_names = Enum.map(roles, & &1.name) |> Enum.sort()
      assert role_names == ["Role1", "Role2"]
    end

    test "returns empty list when user has no roles" do
      org = insert_organization()
      user = insert_user(org)

      assert {:ok, []} = PostgresqlRoleRepository.get_user_roles(user.id)
    end
  end

  describe "get_users_with_role/1" do
    test "returns all user IDs with the role" do
      org = insert_organization()
      user1 = insert_user(org)
      user2 = insert_user(org)
      user3 = insert_user(org)
      role = insert_role(org, "CommonRole", ["scope"])

      insert_user_role(user1, role)
      insert_user_role(user2, role)

      assert {:ok, user_ids} = PostgresqlRoleRepository.get_users_with_role(role.id)
      assert length(user_ids) == 2
      assert user1.id in user_ids
      assert user2.id in user_ids
      refute user3.id in user_ids
    end

    test "returns empty list when no users have the role" do
      org = insert_organization()
      role = insert_role(org, "UnusedRole", ["scope"])

      assert {:ok, []} = PostgresqlRoleRepository.get_users_with_role(role.id)
    end
  end

  describe "assign_to_user/3" do
    test "creates user_role assignment" do
      org = insert_organization()
      user = insert_user(org)
      role = insert_role(org, "NewRole", ["scope"])
      admin_user = insert_user(org)
      assigned_by = admin_user.id

      assert {:ok, user_role} =
               PostgresqlRoleRepository.assign_to_user(user.id, role.id, assigned_by)

      assert user_role.user_id == user.id
      assert user_role.role_id == role.id
      assert user_role.assigned_at != nil
    end

    test "handles duplicate assignment gracefully" do
      org = insert_organization()
      user = insert_user(org)
      role = insert_role(org, "DuplicateRole", ["scope"])

      assert {:ok, _} = PostgresqlRoleRepository.assign_to_user(user.id, role.id, nil)
      # Second assignment should use on_conflict: :nothing
      assert {:ok, _} = PostgresqlRoleRepository.assign_to_user(user.id, role.id, nil)
    end
  end

  describe "revoke_from_user/2" do
    test "removes user_role assignment" do
      org = insert_organization()
      user = insert_user(org)
      role = insert_role(org, "RoleToRevoke", ["scope"])
      insert_user_role(user, role)

      assert :ok = PostgresqlRoleRepository.revoke_from_user(user.id, role.id)
      assert Repo.get_by(UserRoleSchema, user_id: user.id, role_id: role.id) == nil
    end

    test "returns error when assignment doesn't exist" do
      org = insert_organization()
      user = insert_user(org)
      role = insert_role(org, "NeverAssigned", ["scope"])

      assert {:error, :not_found} = PostgresqlRoleRepository.revoke_from_user(user.id, role.id)
    end
  end

  # Test helpers

  defp insert_organization do
    Repo.insert!(%OrganizationSchema{
      id: Ecto.UUID.generate(),
      name: "Test Org #{:rand.uniform(10000)}",
      status: :active,
      plan_type: :free,
      max_users: 10,
      max_api_calls_per_month: 10000,
      support_level: :community,
      api_calls_reset_at: DateTime.utc_now() |> DateTime.truncate(:second),
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp insert_user(org) do
    Repo.insert!(%UserSchema{
      id: Ecto.UUID.generate(),
      organization_id: org.id,
      email: "user#{:rand.uniform(10000)}@example.com",
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      status: :active,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp insert_role(org, name, scopes) do
    Repo.insert!(%RoleSchema{
      id: Ecto.UUID.generate(),
      organization_id: org.id,
      name: name,
      description: "Test role: #{name}",
      scopes: scopes,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp insert_user_role(user, role) do
    Repo.insert!(%UserRoleSchema{
      user_id: user.id,
      role_id: role.id,
      assigned_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end
end
