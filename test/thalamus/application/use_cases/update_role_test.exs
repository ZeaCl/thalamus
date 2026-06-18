defmodule Thalamus.Application.UseCases.UpdateRoleTest do
  use ExUnit.Case, async: false
  import Mox

  alias Thalamus.Application.UseCases.UpdateRole
  alias Thalamus.Domain.Entities.Role

  setup :verify_on_exit!

  @deps %{
    role_repository: Thalamus.MockRoleRepository,
    cache_service: Thalamus.MockCacheService
  }

  describe "execute/2" do
    test "successfully updates role scopes" do
      role_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      user1_id = Ecto.UUID.generate()
      user2_id = Ecto.UUID.generate()

      existing_role = %Role{
        id: role_id,
        organization_id: org_id,
        name: "Developer",
        scopes: ["read:code"],
        description: "Dev role"
      }

      updated_role = %Role{
        existing_role
        | scopes: ["read:code", "write:code", "deploy:staging"]
      }

      request = %{
        role_id: role_id,
        scopes: ["read:code", "write:code", "deploy:staging"]
      }

      Thalamus.MockRoleRepository
      |> expect(:find_by_id, fn ^role_id -> {:ok, existing_role} end)
      |> expect(:save, fn role ->
        assert role.scopes == ["read:code", "write:code", "deploy:staging"]
        {:ok, updated_role}
      end)
      |> expect(:get_users_with_role, fn ^role_id ->
        {:ok, [user1_id, user2_id]}
      end)

      Thalamus.MockCacheService
      |> expect(:delete, fn "user_effective_scopes:" <> ^user1_id -> :ok end)
      |> expect(:delete, fn "user_effective_scopes:" <> ^user2_id -> :ok end)

      assert {:ok, result} = UpdateRole.execute(request, @deps)
      assert result.role.scopes == ["read:code", "write:code", "deploy:staging"]
      assert result.invalidated_cache_for == 2
    end

    test "returns error when role not found" do
      role_id = Ecto.UUID.generate()

      request = %{
        role_id: role_id,
        scopes: ["new:scope"]
      }

      Thalamus.MockRoleRepository
      |> expect(:find_by_id, fn ^role_id -> {:error, :not_found} end)

      assert {:error, :not_found} = UpdateRole.execute(request, @deps)
    end

    test "validates new scope format" do
      role_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      existing_role = %Role{
        id: role_id,
        organization_id: org_id,
        name: "TestRole",
        scopes: ["read:data"],
        description: "Test"
      }

      request = %{
        role_id: role_id,
        # Invalid: special char and uppercase
        scopes: ["Invalid!Scope", "UPPERCASE"]
      }

      Thalamus.MockRoleRepository
      |> expect(:find_by_id, fn ^role_id -> {:ok, existing_role} end)

      # Should fail due to invalid scope format
      assert {:error, :invalid_scope_format} = UpdateRole.execute(request, @deps)
    end

    test "invalidates cache for all users with the role" do
      role_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      user_ids = for _ <- 1..5, do: Ecto.UUID.generate()

      existing_role = %Role{
        id: role_id,
        organization_id: org_id,
        name: "CommonRole",
        scopes: ["read:basic"],
        description: "Common"
      }

      request = %{
        role_id: role_id,
        scopes: ["read:advanced"]
      }

      Thalamus.MockRoleRepository
      |> expect(:find_by_id, fn ^role_id -> {:ok, existing_role} end)
      |> expect(:save, fn role -> {:ok, role} end)
      |> expect(:get_users_with_role, fn ^role_id -> {:ok, user_ids} end)

      # Expect cache deletion for each user
      for user_id <- user_ids do
        Thalamus.MockCacheService
        |> expect(:delete, fn "user_effective_scopes:" <> ^user_id -> :ok end)
      end

      assert {:ok, result} = UpdateRole.execute(request, @deps)
      assert result.invalidated_cache_for == 5
    end

    test "handles empty scopes list" do
      role_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      existing_role = %Role{
        id: role_id,
        organization_id: org_id,
        name: "EmptyRole",
        scopes: ["some:scope"],
        description: "Test"
      }

      request = %{
        role_id: role_id,
        scopes: []
      }

      Thalamus.MockRoleRepository
      |> expect(:find_by_id, fn ^role_id -> {:ok, existing_role} end)
      |> expect(:save, fn role ->
        assert role.scopes == []
        {:ok, %{role | scopes: []}}
      end)
      |> expect(:get_users_with_role, fn ^role_id -> {:ok, []} end)

      assert {:ok, result} = UpdateRole.execute(request, @deps)
      assert result.role.scopes == []
    end

    test "handles cache deletion failures gracefully" do
      role_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      existing_role = %Role{
        id: role_id,
        organization_id: org_id,
        name: "TestRole",
        scopes: ["read:old"],
        description: "Test"
      }

      request = %{
        role_id: role_id,
        scopes: ["read:new"]
      }

      Thalamus.MockRoleRepository
      |> expect(:find_by_id, fn ^role_id -> {:ok, existing_role} end)
      |> expect(:save, fn role -> {:ok, role} end)
      |> expect(:get_users_with_role, fn ^role_id -> {:ok, [user_id]} end)

      Thalamus.MockCacheService
      |> expect(:delete, fn _ -> raise "Cache error" end)

      # Should complete successfully even if cache deletion fails
      assert {:ok, result} = UpdateRole.execute(request, @deps)
      assert result.invalidated_cache_for == 1
    end
  end
end
