defmodule Thalamus.Application.UseCases.DeleteRoleTest do
  use ExUnit.Case, async: true
  import Mox

  alias Thalamus.Application.UseCases.DeleteRole

  setup :verify_on_exit!

  @deps %{
    role_repository: Thalamus.MockRoleRepository,
    cache_service: Thalamus.MockCacheService
  }

  describe "execute/2" do
    test "successfully deletes role and invalidates cache" do
      role_id = Ecto.UUID.generate()
      user1_id = Ecto.UUID.generate()
      user2_id = Ecto.UUID.generate()

      request = %{role_id: role_id}

      Thalamus.MockRoleRepository
      |> expect(:get_users_with_role, fn ^role_id ->
        {:ok, [user1_id, user2_id]}
      end)
      |> expect(:delete, fn ^role_id -> {:ok, 1} end)

      Thalamus.MockCacheService
      |> expect(:delete, fn "user_effective_scopes:" <> ^user1_id -> :ok end)
      |> expect(:delete, fn "user_effective_scopes:" <> ^user2_id -> :ok end)

      assert {:ok, result} = DeleteRole.execute(request, @deps)
      assert result.deleted_role_id == role_id
      assert result.invalidated_cache_for == 2
    end

    test "returns error when role not found" do
      role_id = Ecto.UUID.generate()

      request = %{role_id: role_id}

      Thalamus.MockRoleRepository
      |> expect(:get_users_with_role, fn ^role_id -> {:ok, []} end)
      |> expect(:delete, fn ^role_id -> {:error, :not_found} end)

      assert {:error, :not_found} = DeleteRole.execute(request, @deps)
    end

    test "gets affected users before deletion" do
      role_id = Ecto.UUID.generate()
      user_ids = for _ <- 1..3, do: Ecto.UUID.generate()

      request = %{role_id: role_id}

      # Must get users BEFORE deleting the role
      Thalamus.MockRoleRepository
      |> expect(:get_users_with_role, fn ^role_id -> {:ok, user_ids} end)
      |> expect(:delete, fn ^role_id -> {:ok, 1} end)

      for user_id <- user_ids do
        Thalamus.MockCacheService
        |> expect(:delete, fn "user_effective_scopes:" <> ^user_id -> :ok end)
      end

      assert {:ok, result} = DeleteRole.execute(request, @deps)
      assert result.invalidated_cache_for == 3
    end

    test "handles role with no users" do
      role_id = Ecto.UUID.generate()

      request = %{role_id: role_id}

      Thalamus.MockRoleRepository
      |> expect(:get_users_with_role, fn ^role_id -> {:ok, []} end)
      |> expect(:delete, fn ^role_id -> {:ok, 1} end)

      assert {:ok, result} = DeleteRole.execute(request, @deps)
      assert result.deleted_role_id == role_id
      assert result.invalidated_cache_for == 0
    end

    test "handles cache deletion failures gracefully" do
      role_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      request = %{role_id: role_id}

      Thalamus.MockRoleRepository
      |> expect(:get_users_with_role, fn ^role_id -> {:ok, [user_id]} end)
      |> expect(:delete, fn ^role_id -> {:ok, 1} end)

      Thalamus.MockCacheService
      |> expect(:delete, fn _ -> raise "Cache error" end)

      # Should still complete successfully
      assert {:ok, result} = DeleteRole.execute(request, @deps)
      assert result.deleted_role_id == role_id
      assert result.invalidated_cache_for == 1
    end

    test "invalidates cache for large number of users" do
      role_id = Ecto.UUID.generate()
      user_ids = for _ <- 1..100, do: Ecto.UUID.generate()

      request = %{role_id: role_id}

      Thalamus.MockRoleRepository
      |> expect(:get_users_with_role, fn ^role_id -> {:ok, user_ids} end)
      |> expect(:delete, fn ^role_id -> {:ok, 1} end)

      for user_id <- user_ids do
        Thalamus.MockCacheService
        |> expect(:delete, fn "user_effective_scopes:" <> ^user_id -> :ok end)
      end

      assert {:ok, result} = DeleteRole.execute(request, @deps)
      assert result.invalidated_cache_for == 100
    end
  end
end
