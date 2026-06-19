defmodule Thalamus.Application.UseCases.AssignRoleTest do
  use ExUnit.Case, async: false
  import Mox

  alias Thalamus.Application.UseCases.AssignRole
  alias Thalamus.Domain.Entities.{Role, User}

  # Setup mocks
  setup :verify_on_exit!

  @deps %{
    role_repository: Thalamus.MockRoleRepository,
    user_repository: Thalamus.MockUserRepository,
    cache_service: Thalamus.MockCacheService,
    audit_logger: Thalamus.MockAuditLogger
  }

  describe "execute/2" do
    test "successfully assigns role to user" do
      user_id = Ecto.UUID.generate()
      role_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      assigned_by = Ecto.UUID.generate()

      user = build_user(user_id, org_id, :active)
      role = build_role(role_id, org_id, "Developer", ["read:code"])

      Thalamus.MockUserRepository
      |> expect(:find_by_id, fn ^user_id -> {:ok, user} end)

      Thalamus.MockRoleRepository
      |> expect(:find_by_id, fn ^role_id -> {:ok, role} end)
      |> expect(:assign_to_user, fn ^user_id, ^role_id, _assigned_by ->
        {:ok, %{user_id: user_id, role_id: role_id, assigned_at: DateTime.utc_now()}}
      end)

      Thalamus.MockCacheService
      |> expect(:delete, fn "user_effective_scopes:" <> ^user_id -> :ok end)

      Thalamus.MockAuditLogger
      |> expect(:log, fn log_entry ->
        assert log_entry.event_type == "role.assigned"
        assert log_entry.actor_id == assigned_by
        assert log_entry.resource_id == "#{user_id}:#{role_id}"
        :ok
      end)

      request = %{user_id: user_id, role_id: role_id, assigned_by: assigned_by}
      assert {:ok, result} = AssignRole.execute(request, @deps)
      assert result.user_id == user_id
      assert result.role_id == role_id
    end

    test "returns error when user not found" do
      user_id = Ecto.UUID.generate()
      role_id = Ecto.UUID.generate()

      Thalamus.MockUserRepository
      |> expect(:find_by_id, fn ^user_id -> {:error, :not_found} end)

      request = %{user_id: user_id, role_id: role_id, assigned_by: nil}
      assert {:error, :not_found} = AssignRole.execute(request, @deps)
    end

    test "returns error when role not found" do
      user_id = Ecto.UUID.generate()
      role_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      user = build_user(user_id, org_id, :active)

      Thalamus.MockUserRepository
      |> expect(:find_by_id, fn ^user_id -> {:ok, user} end)

      Thalamus.MockRoleRepository
      |> expect(:find_by_id, fn ^role_id -> {:error, :not_found} end)

      request = %{user_id: user_id, role_id: role_id, assigned_by: nil}
      assert {:error, :not_found} = AssignRole.execute(request, @deps)
    end

    test "returns error when user is not active" do
      user_id = Ecto.UUID.generate()
      role_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      user = build_user(user_id, org_id, :suspended)
      role = build_role(role_id, org_id, "Admin", ["admin:all"])

      Thalamus.MockUserRepository
      |> expect(:find_by_id, fn ^user_id -> {:ok, user} end)

      # Note: role_repository.find_by_id is NOT called because user validation fails first

      request = %{user_id: user_id, role_id: role_id, assigned_by: nil}
      assert {:error, :user_not_active} = AssignRole.execute(request, @deps)
    end

    test "returns error when user and role are in different organizations" do
      user_id = Ecto.UUID.generate()
      role_id = Ecto.UUID.generate()
      user_org_id = Ecto.UUID.generate()
      role_org_id = Ecto.UUID.generate()

      user = build_user(user_id, user_org_id, :active)
      role = build_role(role_id, role_org_id, "Manager", ["manage:team"])

      Thalamus.MockUserRepository
      |> expect(:find_by_id, fn ^user_id -> {:ok, user} end)

      Thalamus.MockRoleRepository
      |> expect(:find_by_id, fn ^role_id -> {:ok, role} end)

      request = %{user_id: user_id, role_id: role_id, assigned_by: nil}
      assert {:error, :organization_mismatch} = AssignRole.execute(request, @deps)
    end
  end

  # Test helpers

  defp build_user(id, org_id, status) do
    %User{
      id: id,
      organization_id: org_id,
      email: "user@example.com",
      status: status,
      email_verified: true
    }
  end

  defp build_role(id, org_id, name, scopes) do
    %Role{
      id: id,
      organization_id: org_id,
      name: name,
      scopes: scopes,
      description: "Test role"
    }
  end
end
